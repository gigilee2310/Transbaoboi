import CoreGraphics
import Foundation

/// One recognized line of text. `rect` is in pixel coordinates of the working image, origin top-left.
struct OCRLine: Identifiable, Equatable, Sendable, Codable {
    let id: Int
    let text: String
    let rect: CGRect
    let confidence: Float
}

/// A group of lines that belong together (paragraph, bubble, button label…).
struct TextBlock: Identifiable, Equatable, Sendable, Codable {
    let id: Int
    let lines: [OCRLine]

    var rect: CGRect {
        lines.dropFirst().reduce(lines.first?.rect ?? .zero) { $0.union($1.rect) }
    }

    var averageLineHeight: CGFloat {
        guard !lines.isEmpty else { return 0 }
        return lines.map(\.rect.height).reduce(0, +) / CGFloat(lines.count)
    }

    /// Lines joined: no separator for Chinese, a space for Korean and Latin text.
    var text: String { TextJoiner.join(lines.map(\.text)) }

    /// Single short line: buttons, tabs, labels. Rendered on one line, centered.
    var isShortLabel: Bool {
        lines.count == 1 && LayoutGrouper.isShort(lines[0].text)
    }
}

enum SourceLanguage: String, CaseIterable, Identifiable, Sendable, Codable {
    case chineseSimplified = "zh-Hans"
    case chineseTraditional = "zh-Hant"
    case korean = "ko"
    case english = "en"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .chineseSimplified: "Trung (giản thể)"
        case .chineseTraditional: "Trung (phồn thể)"
        case .korean: "Hàn"
        case .english: "Anh"
        }
    }

    var localeLanguage: Locale.Language { Locale.Language(identifier: rawValue) }

    /// Identifier for Vision text recognition.
    var visionCode: String {
        switch self {
        case .chineseSimplified: "zh-Hans"
        case .chineseTraditional: "zh-Hant"
        case .korean: "ko-KR"
        case .english: "en-US"
        }
    }
}

enum TextJoiner {
    static func join(_ parts: [String]) -> String {
        var result = ""
        for part in parts {
            let trimmed = part.trimmingCharacters(in: .whitespaces)
            guard !trimmed.isEmpty else { continue }
            if let last = result.unicodeScalars.last, let first = trimmed.unicodeScalars.first,
               !(Script.isSpacelessCJK(last) || Script.isSpacelessCJK(first)), last != "-" {
                result += " "
            }
            result += trimmed
        }
        return result
    }
}

enum Script {
    static func isHan(_ s: Unicode.Scalar) -> Bool {
        switch s.value {
        case 0x4E00...0x9FFF, 0x3400...0x4DBF, 0x20000...0x2A6DF, 0xF900...0xFAFF: true
        default: false
        }
    }

    static func isHangul(_ s: Unicode.Scalar) -> Bool {
        switch s.value {
        case 0xAC00...0xD7AF, 0x1100...0x11FF, 0x3130...0x318F: true
        default: false
        }
    }

    static func isKana(_ s: Unicode.Scalar) -> Bool {
        (0x3040...0x30FF).contains(s.value)
    }

    /// Han, Hangul, Kana and CJK punctuation / full-width forms.
    static func isCJK(_ s: Unicode.Scalar) -> Bool {
        isHan(s) || isHangul(s) || isKana(s)
            || (0x3000...0x303F).contains(s.value) || (0xFF00...0xFFEF).contains(s.value)
    }

    /// Scripts written without spaces between words (Korean uses spaces, so Hangul is excluded).
    static func isSpacelessCJK(_ s: Unicode.Scalar) -> Bool {
        isCJK(s) && !isHangul(s)
    }

    static func isLatinLetter(_ s: Unicode.Scalar) -> Bool {
        s.properties.isAlphabetic && s.value < 0x0250
    }
}
