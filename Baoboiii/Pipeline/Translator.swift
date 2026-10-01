import CoreGraphics
import Foundation

struct TranslationItem: Sendable, Equatable {
    let id: Int
    let text: String
    let language: SourceLanguage
}

protocol Translator: Sendable {
    var engine: TranslationEngine { get }
    /// Translates all items to Vietnamese. `context` is the full screenshot, for engines that can use it.
    /// Returns translations keyed by item id; missing ids are left untranslated.
    func translate(_ items: [TranslationItem], context: CGImage?) async throws -> [Int: String]
}
