import CoreGraphics
import Foundation

/// OCR + grouping + language detection. First half of the pipeline.
struct ScreenAnalysis: Sendable {
    let image: CGImage
    let lines: [OCRLine]
    let blocks: [TextBlock]
    /// Blocks to translate, with their detected language. Blocks missing here are left untouched.
    let languages: [Int: SourceLanguage]
}

struct ScreenAnalyzer: Sendable {
    var ocr: any OCRService = VisionOCRService()
    var grouper = LayoutGrouper()

    func analyze(_ image: CGImage, preferred: SourceLanguage?) async throws -> ScreenAnalysis {
        let lines = try await ocr.recognize(image, language: preferred)
        guard !lines.isEmpty else { throw BaoboiiiError.noTextFound }
        let blocks = grouper.group(lines)

        let width = CGFloat(image.width), height = CGFloat(image.height)
        let isPhoneScreenshot = height / max(width, 1) > 1.9
        var languages: [Int: SourceLanguage] = [:]
        for block in blocks {
            // Skip the status bar (clock, carrier, battery) on full-screen screenshots.
            if isPhoneScreenshot && block.rect.maxY < height * 0.055 { continue }
            if let lang = LanguageDetector.detect(block.text, preferred: preferred) {
                languages[block.id] = lang
            }
        }
        return ScreenAnalysis(image: image, lines: lines, blocks: blocks, languages: languages)
    }
}
