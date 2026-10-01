import XCTest
@testable import Baoboiii

final class LanguageDetectorTests: XCTestCase {
    func testDetectsScripts() {
        XCTAssertEqual(LanguageDetector.detect("안녕하세요 여러분", preferred: nil), .korean)
        XCTAssertEqual(LanguageDetector.detect("今天天气很好", preferred: nil), .chineseSimplified)
        XCTAssertEqual(LanguageDetector.detect("Hello everyone", preferred: nil), .english)
    }

    func testPreferredChineseVariantWins() {
        XCTAssertEqual(LanguageDetector.detect("今天天氣很好", preferred: .chineseTraditional), .chineseTraditional)
    }

    func testSkipsUntranslatable() {
        XCTAssertNil(LanguageDetector.detect("12:30", preferred: nil))
        XCTAssertNil(LanguageDetector.detect("@someone_123", preferred: nil))
        XCTAssertNil(LanguageDetector.detect("https://example.com", preferred: nil))
        XCTAssertNil(LanguageDetector.detect("Xin chào các bạn", preferred: nil))
        XCTAssertNil(LanguageDetector.detect("こんにちは", preferred: nil))
        XCTAssertNil(LanguageDetector.detect("❤️ 😂", preferred: nil))
    }
}
