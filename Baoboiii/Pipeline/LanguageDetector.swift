import Foundation
import NaturalLanguage

enum LanguageDetector {
    /// Returns the language to translate from, or nil when the block should be left untouched
    /// (numbers, usernames, links, Vietnamese, Japanese…).
    static func detect(_ text: String, preferred: SourceLanguage?) -> SourceLanguage? {
        if shouldSkip(text) { return nil }

        var han = 0, hangul = 0, kana = 0, latin = 0
        for s in text.unicodeScalars {
            if Script.isHan(s) { han += 1 }
            else if Script.isHangul(s) { hangul += 1 }
            else if Script.isKana(s) { kana += 1 }
            else if Script.isLatinLetter(s) { latin += 1 }
        }

        if hangul > 0 && hangul >= han { return .korean }
        if kana >= 2 || (kana > 0 && han == 0) { return nil }  // Japanese is out of scope
        if han > 0 {
            if preferred == .chineseSimplified || preferred == .chineseTraditional { return preferred }
            return chineseVariant(text)
        }
        if latin >= 2 && !isVietnamese(text) { return .english }
        return nil
    }

    static func chineseVariant(_ text: String) -> SourceLanguage {
        let recognizer = NLLanguageRecognizer()
        recognizer.languageConstraints = [.simplifiedChinese, .traditionalChinese]
        recognizer.processString(text)
        return recognizer.dominantLanguage == .traditionalChinese ? .chineseTraditional : .chineseSimplified
    }

    static func isVietnamese(_ text: String) -> Bool {
        let special: Set<Character> = ["ă", "â", "đ", "ê", "ô", "ơ", "ư", "Ă", "Â", "Đ", "Ê", "Ô", "Ơ", "Ư"]
        for ch in text {
            if special.contains(ch) { return true }
            for s in ch.unicodeScalars where (0x1EA0...0x1EF9).contains(s.value) { return true }
        }
        return false
    }

    /// Text that should never be translated.
    static func shouldSkip(_ text: String) -> Bool {
        let t = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if t.isEmpty { return true }
        if t.hasPrefix("@") && !t.contains(" ") { return true }
        let lower = t.lowercased()
        if lower.hasPrefix("http") || lower.hasPrefix("www.") { return true }
        // Only digits, punctuation, symbols, emoji (times, counters, prices…).
        let hasLetter = t.unicodeScalars.contains { $0.properties.isAlphabetic }
        return !hasLetter
    }
}
