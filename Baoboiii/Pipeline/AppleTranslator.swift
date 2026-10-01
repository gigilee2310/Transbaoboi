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
///
/// Speed: in the background each request costs ~1 s, so a screen with 30 blocks took 30 s when
/// translated block by block. All blocks of one language are now sent as ONE string (one block per
/// line) and split back; if the line count doesn't match we fall back to per-block requests.
/// Languages run in parallel, and Simplified/Traditional Chinese on one screen share one session.
struct AppleTranslator: Translator {
    let engine = TranslationEngine.apple
    static let target = Locale.Language(identifier: "vi")

    static func status(for language: SourceLanguage) async -> LanguageAvailability.Status {
        let availability = LanguageAvailability()
        return (try? await availability.status(from: language.localeLanguage, to: target)) ?? .unsupported
    }

    func translate(_ items: [TranslationItem], context: CGImage?) async throws -> [Int: String] {
        var groups = Dictionary(grouping: items, by: \.language)
        Self.mergeChinese(&groups)

        var missing: [SourceLanguage] = []
        for language in SourceLanguage.allCases where groups[language] != nil {
            if await Self.status(for: language) != .installed { missing.append(language) }
        }
        DiagnosticsLog.log("Apple: gói cần dùng \(groups.keys.map(\.rawValue).sorted()), thiếu \(missing.map(\.rawValue))")
        if !missing.isEmpty { throw BaoboiiiError.languagePackMissing(missing) }

        return try await withThrowingTaskGroup(of: [Int: String].self) { group in
            for (language, list) in groups {
                let pairs = list.map { (id: $0.id, text: $0.text) }
                group.addTask { try await Self.translateBatched(pairs, from: language) }
            }
            var result: [Int: String] = [:]
            for try await part in group { result.merge(part) { $1 } }
            return result
        }
    }

    /// Puts Simplified and Traditional Chinese blocks of one screen into the bigger group (one model load).
    static func mergeChinese(_ groups: inout [SourceLanguage: [TranslationItem]]) {
        guard let hans = groups[.chineseSimplified], let hant = groups[.chineseTraditional] else { return }
        let keep: SourceLanguage = hans.count >= hant.count ? .chineseSimplified : .chineseTraditional
        let merged = (hans + hant).map { TranslationItem(id: $0.id, text: $0.text, language: keep) }
        groups[.chineseSimplified] = nil
        groups[.chineseTraditional] = nil
        groups[keep] = merged
    }

    @MainActor
    private static func translateBatched(_ items: [(id: Int, text: String)], from language: SourceLanguage) async throws -> [Int: String] {
        let clock = Stopwatch()
        let session = TranslationSession(installedSource: language.localeLanguage, target: target)
        DiagnosticsLog.log("Apple: mở phiên \(language.rawValue)→vi, \(items.count) khối")
        do {
            if items.count > 1 {
                let lines = items.map { $0.text.replacingOccurrences(of: "\n", with: " ") }
                let response = try await session.translate(lines.joined(separator: "\n"))
                let out = response.targetText
                    .components(separatedBy: "\n")
                    .map { $0.trimmingCharacters(in: .whitespaces) }
                    .filter { !$0.isEmpty }
                if out.count == items.count {
                    DiagnosticsLog.log("Apple: xong \(language.rawValue) gộp 1 lần (\(clock.ms) ms)")
                    return Dictionary(uniqueKeysWithValues: zip(items.map(\.id), out))
                }
                DiagnosticsLog.log("Apple: gộp lệch dòng (\(out.count)/\(items.count)), dịch từng khối")
            }
            let requests = items.map { TranslationSession.Request(sourceText: $0.text, clientIdentifier: String($0.id)) }
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
