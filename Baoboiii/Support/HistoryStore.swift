import UIKit

/// A translation result as shown by ResultView. Can be built from a fresh run or loaded from history.
struct ResultModel: Identifiable, Hashable {
    let id: UUID
    let date: Date
    let original: UIImage
    let translated: UIImage
    let lines: [OCRLine]
    let textBlocks: [TextBlock]
    let languages: [Int: SourceLanguage]
    let blocks: [TranslatedBlock]
    let engine: TranslationEngine?
    let notice: String?

    static func == (a: ResultModel, b: ResultModel) -> Bool { a.id == b.id }
    func hash(into hasher: inout Hasher) { hasher.combine(id) }

    init(outcome: TranslationOutcome) {
        id = UUID()
        date = Date()
        original = UIImage(cgImage: outcome.original)
        translated = outcome.translated
        lines = outcome.analysis.lines
        textBlocks = outcome.analysis.blocks
        languages = outcome.analysis.languages
        blocks = outcome.blocks
        engine = outcome.engine
        notice = outcome.notice
    }

    init(id: UUID, date: Date, original: UIImage, translated: UIImage, meta: HistoryStore.Meta) {
        self.id = id
        self.date = date
        self.original = original
        self.translated = translated
        lines = meta.lines
        textBlocks = meta.textBlocks
        languages = meta.languages
        blocks = meta.blocks
        engine = meta.engine
        notice = meta.notice
    }

    var allTranslations: String {
        blocks.sorted { ($0.frame.minY, $0.frame.minX) < ($1.frame.minY, $1.frame.minX) }
            .map(\.translation)
            .joined(separator: "\n\n")
    }

    func debugImage() -> UIImage? {
        guard let cg = original.cgImage else { return nil }
        return DebugRenderer.render(image: cg, lines: lines, blocks: textBlocks, tags: languages.mapValues(\.rawValue))
    }
}

/// Keeps the last 20 translations on disk (Application Support/History/<uuid>/).
enum HistoryStore {
    static let limit = 20

    struct Meta: Codable {
        let date: Date
        let lines: [OCRLine]
        let textBlocks: [TextBlock]
        let languages: [Int: SourceLanguage]
        let blocks: [TranslatedBlock]
        let engine: TranslationEngine?
        let notice: String?
    }

    struct Entry: Identifiable, Hashable {
        let id: UUID
        let date: Date
        let folder: URL
        let preview: String

        var thumbnailURL: URL { folder.appendingPathComponent("translated.jpg") }
    }

    static var directory: URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        return base.appendingPathComponent("History", isDirectory: true)
    }

    static func save(_ model: ResultModel) {
        let folder = directory.appendingPathComponent(model.id.uuidString, isDirectory: true)
        do {
            try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
            if let data = model.original.jpegData(compressionQuality: 0.85) {
                try data.write(to: folder.appendingPathComponent("original.jpg"))
            }
            if let data = model.translated.jpegData(compressionQuality: 0.9) {
                try data.write(to: folder.appendingPathComponent("translated.jpg"))
            }
            let meta = Meta(date: model.date, lines: model.lines, textBlocks: model.textBlocks,
                            languages: model.languages, blocks: model.blocks, engine: model.engine, notice: model.notice)
            try JSONEncoder().encode(meta).write(to: folder.appendingPathComponent("meta.json"))
            prune()
        } catch {
            try? FileManager.default.removeItem(at: folder)
        }
    }

    static func entries() -> [Entry] {
        let folders = (try? FileManager.default.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil)) ?? []
        return folders.compactMap { folder -> Entry? in
            guard let id = UUID(uuidString: folder.lastPathComponent),
                  let data = try? Data(contentsOf: folder.appendingPathComponent("meta.json")),
                  let meta = try? JSONDecoder().decode(Meta.self, from: data) else { return nil }
            let preview = meta.blocks.first?.translation ?? "Không có bản dịch"
            return Entry(id: id, date: meta.date, folder: folder, preview: preview)
        }
        .sorted { $0.date > $1.date }
    }

    static func load(_ entry: Entry) -> ResultModel? {
        guard let data = try? Data(contentsOf: entry.folder.appendingPathComponent("meta.json")),
              let meta = try? JSONDecoder().decode(Meta.self, from: data),
              let original = UIImage(contentsOfFile: entry.folder.appendingPathComponent("original.jpg").path),
              let translated = UIImage(contentsOfFile: entry.folder.appendingPathComponent("translated.jpg").path)
        else { return nil }
        return ResultModel(id: entry.id, date: meta.date, original: original, translated: translated, meta: meta)
    }

    static func delete(_ entry: Entry) {
        try? FileManager.default.removeItem(at: entry.folder)
    }

    static func deleteAll() {
        try? FileManager.default.removeItem(at: directory)
    }

    private static func prune() {
        for entry in entries().dropFirst(limit) { delete(entry) }
    }
}
