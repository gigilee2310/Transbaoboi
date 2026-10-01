import CoreGraphics
import Foundation

/// Translation with the Gemini API: all blocks in a single request, screenshot attached as context.
struct GeminiTranslator: Translator {
    let engine = TranslationEngine.gemini
    let apiKey: String
    let model: String
    let sendImage: Bool
    var timeout: TimeInterval = 30

    static let systemPrompt = """
    You translate on-screen text from a phone screenshot into natural Vietnamese. The apps are mostly \
    Chinese / Korean / English social media (Xiaohongshu/RedNote, Weibo, Douyin, Instagram), \
    Korean webtoons and comics, news and shopping apps.

    Input: a JSON array of objects {"id": number, "text": string, "lang": "zh-Hans" | "zh-Hant" | "ko" | "en"}.
    Output: a JSON array of objects {"id": number, "vi": string}, exactly one object for every input id.

    Rules:
    - Write natural, idiomatic Vietnamese in the register of the source: casual and lively for posts, \
    comments and comic dialogue; neutral for news. Never translate word-for-word.
    - Pick Vietnamese pronouns (anh/em, cậu/tớ, mình/bạn, chị/em, ông/bà…) from the context of the \
    screenshot and keep them consistent between related texts.
    - Keep usernames, brand names, product names and hashtag names as they are. Chinese personal names \
    go to Hán-Việt (王小明 → Vương Tiểu Minh); Korean names are romanized (김민지 → Kim Min-ji).
    - Interface text (buttons, tabs, menus, counters) must be short, phrased the way Vietnamese apps \
    phrase them (关注 → Theo dõi, 点赞 → Thích, 팔로우 → Theo dõi, Share → Chia sẻ).
    - Keep emoji, numbers and units unchanged. Keep each translation as concise as the meaning allows, \
    because it must fit in the same space on screen. Do not add notes or explanations.
    - Lines may have been split by OCR; translate each item as a whole sentence or phrase.
    - If an item is already Vietnamese or must not be translated, return it unchanged.
    - The image (if attached) is only context. Translate only the given items.
    """

    func translate(_ items: [TranslationItem], context: CGImage?) async throws -> [Int: String] {
        guard !items.isEmpty else { return [:] }
        let payload = items.map { ["id": $0.id, "text": $0.text, "lang": $0.language.rawValue] as [String: Any] }
        let itemsJSON = String(data: try JSONSerialization.data(withJSONObject: payload, options: [.withoutEscapingSlashes]), encoding: .utf8) ?? "[]"

        var parts: [[String: Any]] = [["text": "Translate these items to Vietnamese:\n\(itemsJSON)"]]
        if sendImage, let context {
            let small = ImageLoader.scaled(context, maxPixelSize: 1280)
            if let jpeg = ImageLoader.jpegData(small, quality: 0.6) {
                parts.append(["inlineData": ["mimeType": "image/jpeg", "data": jpeg.base64EncodedString()]])
            }
        }

        do {
            return try await send(parts: parts, lowThinking: true)
        } catch BaoboiiiError.gemini(let status, _) where status == 400 {
            // Older / different models may reject thinkingConfig: retry once without it.
            return try await send(parts: parts, lowThinking: false)
        }
    }

    private func send(parts: [[String: Any]], lowThinking: Bool) async throws -> [Int: String] {
        var generationConfig: [String: Any] = [
            "responseMimeType": "application/json",
            "responseSchema": [
                "type": "ARRAY",
                "items": [
                    "type": "OBJECT",
                    "properties": ["id": ["type": "INTEGER"], "vi": ["type": "STRING"]],
                    "required": ["id", "vi"],
                ],
            ],
        ]
        if lowThinking { generationConfig["thinkingConfig"] = ["thinkingLevel": "low"] }

        let body: [String: Any] = [
            "systemInstruction": ["parts": [["text": Self.systemPrompt]]],
            "contents": [["role": "user", "parts": parts]],
            "generationConfig": generationConfig,
        ]

        let modelPath = model.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? model
        guard let url = URL(string: "https://generativelanguage.googleapis.com/v1beta/models/\(modelPath):generateContent") else {
            throw BaoboiiiError.gemini(status: 404, message: model)
        }
        var request = URLRequest(url: url, timeoutInterval: timeout)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(apiKey, forHTTPHeaderField: "x-goog-api-key")
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let result: (Data, URLResponse)
        do {
            result = try await URLSession.shared.data(for: request)
        } catch let error as URLError where error.code == .timedOut {
            throw BaoboiiiError.timeout
        } catch {
            throw BaoboiiiError.network(error.localizedDescription)
        }

        let (data, response) = result
        let status = (response as? HTTPURLResponse)?.statusCode ?? 0
        guard status == 200 else {
            throw BaoboiiiError.gemini(status: status, message: GeminiParser.errorMessage(data) ?? "HTTP \(status)")
        }
        let text = try GeminiParser.responseText(data)
        return try GeminiParser.translations(text)
    }
}

/// Parsing helpers, kept separate so they can be unit-tested.
enum GeminiParser {
    /// Concatenates the non-thought text parts of the first candidate.
    static func responseText(_ data: Data) throws -> String {
        guard let root = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let candidates = root["candidates"] as? [[String: Any]],
              let content = candidates.first?["content"] as? [String: Any],
              let parts = content["parts"] as? [[String: Any]] else {
            throw BaoboiiiError.badResponse
        }
        let text = parts
            .filter { ($0["thought"] as? Bool) != true }
            .compactMap { $0["text"] as? String }
            .joined()
        guard !text.isEmpty else { throw BaoboiiiError.badResponse }
        return text
    }

    /// Parses `[{"id": 1, "vi": "..."}]`, tolerating code fences, surrounding text and string ids.
    static func translations(_ text: String) throws -> [Int: String] {
        guard let start = text.firstIndex(of: "["), let end = text.lastIndex(of: "]"), start < end,
              let data = String(text[start...end]).data(using: .utf8),
              let array = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]] else {
            throw BaoboiiiError.badResponse
        }
        var result: [Int: String] = [:]
        for entry in array {
            let id: Int?
            if let n = entry["id"] as? Int { id = n }
            else if let s = entry["id"] as? String { id = Int(s) }
            else { id = nil }
            guard let id, let vi = entry["vi"] as? String else { continue }
            let trimmed = vi.trimmingCharacters(in: .whitespacesAndNewlines)
            if !trimmed.isEmpty { result[id] = trimmed }
        }
        guard !result.isEmpty else { throw BaoboiiiError.badResponse }
        return result
    }

    static func errorMessage(_ data: Data) -> String? {
        guard let root = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let error = root["error"] as? [String: Any] else { return nil }
        return error["message"] as? String
    }
}
