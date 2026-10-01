import CoreGraphics
import Foundation
import Vision

protocol OCRService: Sendable {
    /// `language == nil` means automatic detection.
    func recognize(_ image: CGImage, language: SourceLanguage?) async throws -> [OCRLine]
}

struct VisionOCRService: OCRService {
    func recognize(_ image: CGImage, language: SourceLanguage?) async throws -> [OCRLine] {
        try await Task.detached(priority: .userInitiated) {
            try Self.recognizeSync(image, language: language)
        }.value
    }

    static func recognizeSync(_ image: CGImage, language: SourceLanguage?) throws -> [OCRLine] {
        let languages: [String]
        if let language {
            languages = language == .english ? ["en-US"] : [language.visionCode, "en-US"]
        } else {
            languages = ["zh-Hans", "zh-Hant", "ko-KR", "en-US"]
        }
        do {
            return try perform(image, languages: languages, automatic: language == nil)
        } catch {
            // Some language combinations are rejected by Vision; fall back to pure auto-detection.
            return try perform(image, languages: [], automatic: true)
        }
    }

    private static func perform(_ image: CGImage, languages: [String], automatic: Bool) throws -> [OCRLine] {
        let request = VNRecognizeTextRequest()
        request.recognitionLevel = .accurate
        request.usesLanguageCorrection = true
        if !languages.isEmpty { request.recognitionLanguages = languages }
        request.automaticallyDetectsLanguage = automatic

        let handler = VNImageRequestHandler(cgImage: image, options: [:])
        try handler.perform([request])

        let w = CGFloat(image.width), h = CGFloat(image.height)
        var lines: [OCRLine] = []
        for observation in request.results ?? [] {
            guard let candidate = observation.topCandidates(1).first else { continue }
            let text = candidate.string.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !text.isEmpty else { continue }
            let box = observation.boundingBox  // normalized, origin bottom-left
            let rect = CGRect(x: box.minX * w, y: (1 - box.maxY) * h, width: box.width * w, height: box.height * h)
            lines.append(OCRLine(id: lines.count, text: text, rect: rect.integral, confidence: candidate.confidence))
        }
        return lines
    }
}
