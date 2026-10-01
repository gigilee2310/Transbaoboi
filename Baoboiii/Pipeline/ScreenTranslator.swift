import UIKit

struct TranslatedBlock: Identifiable, Codable, Sendable, Equatable {
    let id: Int
    let original: String
    let translation: String
    let language: SourceLanguage
    /// Where the translation was drawn (pixels, top-left origin).
    let frame: CGRect
}

/// Everything produced by one run, used by the result screen, history and the App Intent.
struct TranslationOutcome: Sendable {
    let original: CGImage
    let translated: UIImage
    let analysis: ScreenAnalysis
    let blocks: [TranslatedBlock]
    let engine: TranslationEngine?
    /// Shown to the user, e.g. when the engine fell back to the other one.
    let notice: String?
}

/// Full pipeline: OCR → grouping → translation (with cache + fallback) → inpainting → rendering.
struct ScreenTranslator: Sendable {
    var analyzer = ScreenAnalyzer()
    var inpainter: any Inpainter = MedianFillInpainter()
    var renderer = TextRenderer()
    var cache = TranslationCache.shared

    /// Time limits per step. In the background (Shortcuts) iOS gives an intent roughly 30 s in total,
    /// so each step fails with a clear message instead of the whole run being killed silently.
    var ocrTimeout: Double = 60
    var translateTimeout: Double = 60

    static let background: ScreenTranslator = {
        var t = ScreenTranslator()
        t.ocrTimeout = 10
        t.translateTimeout = 14
        return t
    }()

    func run(imageData: Data, settings: AppSettings = .current, maxPixelSize: Int = ImageLoader.maxPixelSize) async throws -> TranslationOutcome {
        let clock = Stopwatch()
        let image = try ImageLoader.cgImage(from: imageData, maxPixelSize: maxPixelSize)
        DiagnosticsLog.log("Ảnh \(imageData.count / 1024) KB → \(image.width)×\(image.height) px (\(clock.ms) ms)")
        return try await run(image: image, settings: settings)
    }

    func run(image: CGImage, settings: AppSettings) async throws -> TranslationOutcome {
        var clock = Stopwatch()
        let analyzer = self.analyzer
        let analysis = try await withTimeout(ocrTimeout, step: "Nhận diện chữ") {
            try await analyzer.analyze(image, preferred: settings.source)
        }
        DiagnosticsLog.log("OCR: \(analysis.lines.count) dòng, \(analysis.blocks.count) khối, \(analysis.languages.count) cần dịch (\(clock.ms) ms)")
        clock = Stopwatch()
        let blocksByID = Dictionary(uniqueKeysWithValues: analysis.blocks.map { ($0.id, $0) })
        let items = analysis.blocks.compactMap { block in
            analysis.languages[block.id].map { TranslationItem(id: block.id, text: block.text, language: $0) }
        }
        guard !items.isEmpty else {
            return TranslationOutcome(original: image, translated: UIImage(cgImage: image), analysis: analysis,
                                      blocks: [], engine: nil, notice: BaoboiiiError.nothingToTranslate.message)
        }

        let (translations, engine, notice) = try await translate(items, image: image, settings: settings)
        DiagnosticsLog.log("Dịch (\(engine.rawValue)): \(translations.count)/\(items.count) khối (\(clock.ms) ms)")
        clock = Stopwatch()

        // Inpaint + render only the blocks that got a translation.
        let translatedIDs = items.map(\.id).filter { translations[$0] != nil }
        let regions = Dictionary(uniqueKeysWithValues: translatedIDs.compactMap { id in
            blocksByID[id].map { (id, $0.lines.map(\.rect)) }
        })
        let (cleaned, styles) = inpainter.inpaint(image, regions: regions)

        let renderItems: [RenderItem] = translatedIDs.compactMap { id in
            guard let block = blocksByID[id], let text = translations[id], let style = styles[id] else { return nil }
            return RenderItem(id: id, blockRect: block.rect, lineHeight: block.averageLineHeight,
                              lineCount: block.lines.count, text: text, style: style,
                              isShortLabel: block.isShortLabel, centered: Self.isCentered(block))
        }
        let obstacles = analysis.blocks.map(\.rect)
        let (rendered, frames) = renderer.render(base: cleaned, items: renderItems, obstacles: obstacles)
        DiagnosticsLog.log("Tô nền + vẽ chữ: \(renderItems.count) khối (\(clock.ms) ms)")

        let blocks: [TranslatedBlock] = renderItems.compactMap { item in
            guard let block = blocksByID[item.id], let language = analysis.languages[item.id] else { return nil }
            return TranslatedBlock(id: item.id, original: block.text, translation: item.text,
                                   language: language, frame: frames[item.id] ?? block.rect)
        }
        return TranslationOutcome(original: image, translated: rendered, analysis: analysis,
                                  blocks: blocks, engine: engine, notice: notice)
    }

    /// Lines whose centers line up but whose left edges don't → centered text.
    static func isCentered(_ block: TextBlock) -> Bool {
        guard block.lines.count > 1 else { return false }
        let h = block.averageLineHeight
        let mids = block.lines.map(\.rect.midX), lefts = block.lines.map(\.rect.minX)
        let midSpread = (mids.max() ?? 0) - (mids.min() ?? 0)
        let leftSpread = (lefts.max() ?? 0) - (lefts.min() ?? 0)
        return midSpread < h * 0.5 && leftSpread > h * 0.8
    }

    // MARK: - Translation with cache and fallback

    private func translate(_ items: [TranslationItem], image: CGImage, settings: AppSettings)
        async throws -> ([Int: String], TranslationEngine, String?) {
        let primary = settings.engine
        let fallback: TranslationEngine = primary == .apple ? .gemini : .apple

        do {
            let result = try await translate(items, image: image, engine: primary, settings: settings)
            return (result, primary, nil)
        } catch {
            DiagnosticsLog.log("❌ \(primary.rawValue): \((error as? BaoboiiiError)?.message ?? String(describing: error))")
            let canFallback = fallback == .apple || !(settings.geminiAPIKey ?? "").isEmpty
            guard canFallback else { throw error }
            DiagnosticsLog.log("Thử bộ dịch dự phòng: \(fallback.rawValue)")
            let result: [Int: String]
            do {
                result = try await translate(items, image: image, engine: fallback, settings: settings)
            } catch let fallbackError {
                DiagnosticsLog.log("❌ \(fallback.rawValue): \((fallbackError as? BaoboiiiError)?.message ?? String(describing: fallbackError))")
                throw error
            }
            let reason = (error as? BaoboiiiError)?.message ?? error.localizedDescription
            let notice = "Đã tự chuyển sang \(fallback.displayName) vì: \(reason)"
            return (result, fallback, notice)
        }
    }

    private func translate(_ items: [TranslationItem], image: CGImage, engine: TranslationEngine,
                           settings: AppSettings) async throws -> [Int: String] {
        var result: [Int: String] = [:]
        var missing: [TranslationItem] = []
        for item in items {
            if let cached = await cache.get(item.text, engine: engine) {
                result[item.id] = cached
            } else {
                missing.append(item)
            }
        }
        guard !missing.isEmpty else { return result }

        DiagnosticsLog.log("Cache: \(result.count) có sẵn, \(missing.count) cần dịch bằng \(engine.rawValue)")
        let translator = try makeTranslator(engine, settings: settings)
        let fresh = try await withTimeout(translateTimeout, step: "Dịch (\(engine == .apple ? "Apple" : "Gemini"))") {
            try await translator.translate(missing, context: image)
        }
        for item in missing {
            if let text = fresh[item.id] {
                result[item.id] = text
                await cache.set(item.text, engine: engine, translation: text)
            }
        }
        await cache.save()
        return result
    }

    private func makeTranslator(_ engine: TranslationEngine, settings: AppSettings) throws -> any Translator {
        switch engine {
        case .apple:
            return AppleTranslator()
        case .gemini:
            guard let key = settings.geminiAPIKey, !key.isEmpty else { throw BaoboiiiError.missingAPIKey }
            return GeminiTranslator(apiKey: key, model: settings.geminiModel, sendImage: settings.geminiSendImage)
        }
    }
}
