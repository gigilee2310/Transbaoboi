import Foundation

enum TranslationEngine: String, CaseIterable, Identifiable, Codable, Sendable {
    case apple
    case gemini

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .apple: "Apple (trên máy)"
        case .gemini: "Gemini (AI Google)"
        }
    }
}

/// Snapshot of user preferences, read from UserDefaults (shared by the app UI and the App Intent).
struct AppSettings: Sendable {
    enum Key {
        static let engine = "engine"
        static let source = "sourceLanguage"
        static let geminiModel = "geminiModel"
        static let geminiSendImage = "geminiSendImage"
    }

    static let autoSource = "auto"
    static let defaultGeminiModel = "gemini-3.8-flash"
    static let suggestedGeminiModels = ["gemini-3.8-flash", "gemini-3.5-flash-lite", "gemini-3.5-flash"]

    var engine: TranslationEngine
    /// nil = automatic detection.
    var source: SourceLanguage?
    var geminiModel: String
    var geminiSendImage: Bool
    var geminiAPIKey: String?

    static var current: AppSettings {
        let d = UserDefaults.standard
        let model = d.string(forKey: Key.geminiModel)?.trimmingCharacters(in: .whitespacesAndNewlines)
        return AppSettings(
            engine: TranslationEngine(rawValue: d.string(forKey: Key.engine) ?? "") ?? .apple,
            source: SourceLanguage(rawValue: d.string(forKey: Key.source) ?? autoSource),
            geminiModel: (model?.isEmpty ?? true) ? defaultGeminiModel : model!,
            geminiSendImage: d.object(forKey: Key.geminiSendImage) as? Bool ?? true,
            geminiAPIKey: Keychain.geminiAPIKey
        )
    }
}
