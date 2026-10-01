import CoreGraphics
import Foundation
import Translation

/// On-device translation with Apple's Translation framework.
///
/// Notes on running from an App Intent (no UI):
/// - iOS 26 added `TranslationSession(installedSource:target:)`, which works outside SwiftUI views.
///   Before iOS 26 a session could only come from the `.translationTask` view modifier.
/// - That initializer only works for language packs that are already downloaded. Downloading needs UI,
///   so the app has a "Gói ngôn ngữ Apple" screen (LanguagePackView) that uses `.translationTask` +
///   `prepareTranslation()`. If a pack is missing here we throw `languagePackMissing`, and
///   ScreenTranslator falls back to Gemini when an API key is set.
struct AppleTranslator: Translator {
    let engine = TranslationEngine.apple
    static let target = Locale.Language(identifier: "vi")

    static func status(for language: SourceLanguage) async -> LanguageAvailability.Status {
        let availability = LanguageAvailability()
        return (try? await availability.status(from: language.localeLanguage, to: target)) ?? .unsupported
    }

    func translate(_ items: [TranslationItem], context: CGImage?) async throws -> [Int: String] {
        let groups = Dictionary(grouping: items, by: \.language)

        var missing: [SourceLanguage] = []
        for language in SourceLanguage.allCases where groups[language] != nil {
            if await Self.status(for: language) != .installed { missing.append(language) }
        }
        DiagnosticsLog.log("Apple: gói cần dùng \(groups.keys.map(\.rawValue).sorted()), thiếu \(missing.map(\.rawValue))")
        if !missing.isEmpty { throw BaoboiiiError.languagePackMissing(missing) }

        var result: [Int: String] = [:]
        for (language, group) in groups {
            let pairs = group.map { (id: $0.id, text: $0.text) }
            let translated = try await Self.translate(pairs, from: language)
            result.merge(translated) { $1 }
        }
        return result
    }

    @MainActor
    private static func translate(_ items: [(id: Int, text: String)], from language: SourceLanguage) async throws -> [Int: String] {
        let clock = Stopwatch()
        let session = TranslationSession(installedSource: language.localeLanguage, target: target)
        DiagnosticsLog.log("Apple: mở phiên \(language.rawValue)→vi, dịch \(items.count) khối")
        let requests = items.map { TranslationSession.Request(sourceText: $0.text, clientIdentifier: String($0.id)) }
        do {
            let responses = try await session.translations(from: requests)
            var result: [Int: String] = [:]
            for response in responses {
                if let cid = response.clientIdentifier, let id = Int(cid) {
                    result[id] = response.targetText
                }
            }
            DiagnosticsLog.log("Apple: xong \(language.rawValue) (\(clock.ms) ms)")
            return result
        } catch {
            DiagnosticsLog.log("Apple: lỗi \(language.rawValue): \(String(describing: error))")
            throw BaoboiiiError.appleTranslationFailed(error.localizedDescription)
        }
    }
}
