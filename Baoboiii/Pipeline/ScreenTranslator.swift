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

    func run(imageData: Data, settings: AppSettings = .current) async throws -> TranslationOutcome {
        let image = try ImageLoader.cgImage(from: imageData)
        return try await run(image: image, settings: settings)
    }

    func run(image: CGImage, settings: AppSettings) async throws -> TranslationOutcome {
        let analysis = try await analyzer.analyze(image, preferred: settings.source)
        let blocksByID = Dictionary(uniqueKeysWithValues: analysis.blocks.map { ($0.id, $0) })
        let items = analysis.blocks.compactMap { block in
            analysis.languages[block.id].map { TranslationItem(id: block.id, text: block.text, language: $0) }
        }
        guard !items.isEmpty else {
            return TranslationOutcome(original: image, translated: UIImage(cgImage: image), analysis: analysis,
                                      blocks: [], engine: nil, notice: BaoboiiiError.nothingToTranslate.message)
        }

        let (translations, engine, notice) = try await translate(items, image: image, settings: settings)

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
            let canFallback = fallback == .apple || !(settings.geminiAPIKey ?? "").isEmpty
            guard canFallback, let result = try? await translate(items, image: image, engine: fallback, settings: settings) else {
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

        let translator = try makeTranslator(engine, settings: settings)
        let fresh = try await translator.translate(missing, context: image)
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
