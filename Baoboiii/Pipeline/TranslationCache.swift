import Foundation

/// Translation cache keyed by (engine, source text). Persisted as JSON in Caches.
actor TranslationCache {
    static let shared = TranslationCache(
        fileURL: FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first?
            .appendingPathComponent("translation-cache.json")
    )

    private let fileURL: URL?
    private let capacity: Int
    private var store: [String: String] = [:]
    private var order: [String] = []
    private var loaded = false

    init(fileURL: URL?, capacity: Int = 3000) {
        self.fileURL = fileURL
        self.capacity = capacity
    }

    private struct Entry: Codable {
        let k: String
        let v: String
    }

    private static func key(_ text: String, _ engine: TranslationEngine) -> String {
        "\(engine.rawValue)\u{1F}\(text)"
    }

    private func loadIfNeeded() {
        guard !loaded else { return }
        loaded = true
        guard let fileURL, let data = try? Data(contentsOf: fileURL),
              let entries = try? JSONDecoder().decode([Entry].self, from: data) else { return }
        for entry in entries where store[entry.k] == nil {
            store[entry.k] = entry.v
            order.append(entry.k)
        }
    }

    func get(_ text: String, engine: TranslationEngine) -> String? {
        loadIfNeeded()
        return store[Self.key(text, engine)]
    }

    func set(_ text: String, engine: TranslationEngine, translation: String) {
        loadIfNeeded()
        let k = Self.key(text, engine)
        if store[k] == nil { order.append(k) }
        store[k] = translation
        if order.count > capacity {
            let overflow = order.count - capacity
            for old in order.prefix(overflow) { store[old] = nil }
            order.removeFirst(overflow)
        }
    }

    var count: Int {
        loadIfNeeded()
        return store.count
    }

    func save() {
        guard let fileURL else { return }
        let entries = order.compactMap { k in store[k].map { Entry(k: k, v: $0) } }
        if let data = try? JSONEncoder().encode(entries) {
            try? data.write(to: fileURL, options: .atomic)
        }
    }

    func clear() {
        store = [:]
        order = []
        loaded = true
        if let fileURL { try? FileManager.default.removeItem(at: fileURL) }
    }
}
