import CoreGraphics
import UIKit
import XCTest
@testable import Baoboiii

final class GeminiParserTests: XCTestCase {
    func testParsesPlainJSON() throws {
        let result = try GeminiParser.translations(#"[{"id": 1, "vi": "Xin chào"}, {"id": 2, "vi": "Theo dõi"}]"#)
        XCTAssertEqual(result, [1: "Xin chào", 2: "Theo dõi"])
    }

    func testToleratesFencesAndStringIDs() throws {
        let text = """
        Here you go:
        ```json
        [{"id": "3", "vi": " Thích "}]
        ```
        """
        XCTAssertEqual(try GeminiParser.translations(text), [3: "Thích"])
    }

    func testRejectsGarbage() {
        XCTAssertThrowsError(try GeminiParser.translations("no json here"))
        XCTAssertThrowsError(try GeminiParser.translations("[]"))
    }

    func testResponseTextSkipsThoughts() throws {
        let body = #"{"candidates":[{"content":{"parts":[{"text":"thinking...","thought":true},{"text":"[{\"id\":0,\"vi\":\"Chào\"}]"}]}}]}"#
        let text = try GeminiParser.responseText(Data(body.utf8))
        XCTAssertEqual(try GeminiParser.translations(text), [0: "Chào"])
    }

    func testErrorMessage() {
        let body = #"{"error":{"code":429,"message":"Quota exceeded","status":"RESOURCE_EXHAUSTED"}}"#
        XCTAssertEqual(GeminiParser.errorMessage(Data(body.utf8)), "Quota exceeded")
    }
}

final class TranslationCacheTests: XCTestCase {
    func testStoresPerEngine() async {
        let cache = TranslationCache(fileURL: nil)
        await cache.set("你好", engine: .apple, translation: "Xin chào")
        let apple = await cache.get("你好", engine: .apple)
        let gemini = await cache.get("你好", engine: .gemini)
        XCTAssertEqual(apple, "Xin chào")
        XCTAssertNil(gemini)
    }

    func testEvictsOldest() async {
        let cache = TranslationCache(fileURL: nil, capacity: 2)
        await cache.set("a", engine: .apple, translation: "1")
        await cache.set("b", engine: .apple, translation: "2")
        await cache.set("c", engine: .apple, translation: "3")
        let a = await cache.get("a", engine: .apple)
        let c = await cache.get("c", engine: .apple)
        XCTAssertNil(a)
        XCTAssertEqual(c, "3")
    }

    func testPersists() async {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("cache-\(UUID()).json")
        let first = TranslationCache(fileURL: url)
        await first.set("안녕", engine: .gemini, translation: "Chào")
        await first.save()
        let second = TranslationCache(fileURL: url)
        let value = await second.get("안녕", engine: .gemini)
        XCTAssertEqual(value, "Chào")
    }
}

final class InpainterTests: XCTestCase {
    /// White image with a black "text" bar: after inpainting, the bar must be white.
    func testFillsTextWithSurroundingColor() throws {
        let w = 200, h = 100
        let ctx = try XCTUnwrap(CGContext(data: nil, width: w, height: h, bitsPerComponent: 8, bytesPerRow: 0,
                                          space: CGColorSpace(name: CGColorSpace.sRGB)!,
                                          bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue))
        ctx.setFillColor(CGColor(red: 1, green: 1, blue: 1, alpha: 1))
        ctx.fill(CGRect(x: 0, y: 0, width: w, height: h))
        ctx.setFillColor(CGColor(red: 0, green: 0, blue: 0, alpha: 1))
        ctx.fill(CGRect(x: 50, y: 40, width: 100, height: 20))  // symmetric, so flipping doesn't matter
        let image = try XCTUnwrap(ctx.makeImage())

        let textRect = CGRect(x: 50, y: 40, width: 100, height: 20)
        let (cleaned, styles) = MedianFillInpainter().inpaint(image, regions: [7: [textRect]])
        let style = try XCTUnwrap(styles[7])
        XCTAssertEqual(style.background, .white)
        XCTAssertLessThan(style.text.luminance, 0.1)

        let bitmap = try XCTUnwrap(Bitmap(cleaned))
        XCTAssertEqual(bitmap.pixel(100, 50), .white)
    }

    func testReadableColor() {
        let lightGray = RGB(r: 230, g: 230, b: 230)
        XCTAssertEqual(lightGray.readable(on: .white), .black)
        XCTAssertEqual(RGB.black.readable(on: .white), .black)
    }
}

final class RendererLayoutTests: XCTestCase {
    private func item(_ text: String, rect: CGRect, lines: Int, short: Bool = false) -> RenderItem {
        RenderItem(id: 0, blockRect: rect, lineHeight: rect.height / CGFloat(lines), lineCount: lines, text: text,
                   style: BlockStyle(background: .white, text: .black), isShortLabel: short, centered: false)
    }

    private let screen = CGSize(width: 1179, height: 2556)

    func testShortLabelWidensInsteadOfShrinkingTooMuch() {
        let label = item("Theo dõi", rect: CGRect(x: 500, y: 300, width: 90, height: 45), lines: 1, short: true)
        let layout = TextRenderer.layout(for: label, imageSize: screen, obstacles: [])
        XCTAssertTrue(layout.singleLine)
        XCTAssertGreaterThan(layout.frame.width, 90)
        XCTAssertEqual(layout.frame.midX, 545, accuracy: 1)
        XCTAssertGreaterThanOrEqual(layout.fontSize, 9 * TextRenderer.pixelsPerPoint(imageWidth: screen.width))
    }

    func testParagraphGrowsDownWhenTooLong() {
        let text = String(repeating: "Hôm nay trời đẹp quá, chúng mình cùng nhau đi dạo công viên nhé. ", count: 6)
        let para = item(text, rect: CGRect(x: 40, y: 400, width: 900, height: 100), lines: 2)
        let layout = TextRenderer.layout(for: para, imageSize: screen, obstacles: [])
        XCTAssertGreaterThan(layout.frame.height, 100)
        XCTAssertEqual(layout.frame.minY, 400)
    }

    func testGrowthStopsAtObstacleBelow() {
        let text = String(repeating: "Một câu tiếng Việt khá dài để kiểm tra việc nới khung. ", count: 10)
        let para = item(text, rect: CGRect(x: 40, y: 400, width: 600, height: 100), lines: 2)
        let obstacle = CGRect(x: 40, y: 560, width: 600, height: 50)
        let layout = TextRenderer.layout(for: para, imageSize: screen, obstacles: [obstacle])
        XCTAssertLessThanOrEqual(layout.frame.maxY, obstacle.minY)
    }
}

final class AppleTranslatorGroupingTests: XCTestCase {
    func testMergesChineseVariantsIntoBiggerGroup() {
        var groups: [SourceLanguage: [TranslationItem]] = [
            .chineseSimplified: [TranslationItem(id: 1, text: "你好", language: .chineseSimplified),
                                 TranslationItem(id: 2, text: "谢谢", language: .chineseSimplified)],
            .chineseTraditional: [TranslationItem(id: 3, text: "謝謝", language: .chineseTraditional)],
            .english: [TranslationItem(id: 4, text: "Hello", language: .english)],
        ]
        AppleTranslator.mergeChinese(&groups)
        XCTAssertNil(groups[.chineseTraditional])
        XCTAssertEqual(groups[.chineseSimplified]?.map(\.id).sorted(), [1, 2, 3])
        XCTAssertEqual(groups[.english]?.count, 1)
    }
}
