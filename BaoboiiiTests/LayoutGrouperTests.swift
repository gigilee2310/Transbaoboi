import CoreGraphics
import XCTest
@testable import Baoboiii

final class LayoutGrouperTests: XCTestCase {
    private var nextID = 0

    private func line(_ text: String, x: CGFloat, y: CGFloat, w: CGFloat, h: CGFloat = 40) -> OCRLine {
        defer { nextID += 1 }
        return OCRLine(id: nextID, text: text, rect: CGRect(x: x, y: y, width: w, height: h), confidence: 1)
    }

    private let grouper = LayoutGrouper()

    func testParagraphLinesMerge() {
        let lines = [
            line("今天天气很好我们一起去公园散步吧", x: 40, y: 100, w: 900),
            line("然后去吃好吃的火锅和烤肉怎么样呢", x: 40, y: 150, w: 880),
            line("好不好呀朋友们快点回复我", x: 40, y: 200, w: 600),
        ]
        let blocks = grouper.group(lines)
        XCTAssertEqual(blocks.count, 1)
        XCTAssertEqual(blocks[0].lines.count, 3)
        XCTAssertFalse(blocks[0].text.contains(" "), "CJK lines are joined without spaces")
    }

    func testLargeGapSplits() {
        let lines = [
            line("第一段的文字内容比较长一些", x: 40, y: 100, w: 800),
            line("第二段的文字内容比较长一些", x: 40, y: 200, w: 800),  // gap 60 > 0.8 * 40
        ]
        XCTAssertEqual(grouper.group(lines).count, 2)
    }

    func testDifferentHeightSplits() {
        let lines = [
            line("This is a big title line here", x: 40, y: 100, w: 800, h: 60),
            line("and this is small body text below it", x: 40, y: 165, w: 800, h: 36),
        ]
        XCTAssertEqual(grouper.group(lines).count, 2)
    }

    func testMisalignedColumnsSplit() {
        let lines = [
            line("왼쪽 열에 있는 긴 문장입니다 정말로", x: 40, y: 100, w: 400),
            line("오른쪽 열에 있는 긴 문장입니다 정말로", x: 600, y: 150, w: 400),
        ]
        XCTAssertEqual(grouper.group(lines).count, 2)
    }

    func testStackedShortLabelsStaySeparate() {
        let lines = [
            line("关注", x: 100, y: 100, w: 80),
            line("粉丝", x: 100, y: 150, w: 80),
            line("获赞", x: 100, y: 200, w: 80),
        ]
        let blocks = grouper.group(lines)
        XCTAssertEqual(blocks.count, 3)
        XCTAssertTrue(blocks.allSatisfy(\.isShortLabel))
    }

    func testShortTailJoinsParagraph() {
        let lines = [
            line("오늘 정말 재미있는 하루였어요 다들 고마워요", x: 40, y: 100, w: 900),
            line("사랑해요", x: 40, y: 150, w: 160),
        ]
        let blocks = grouper.group(lines)
        XCTAssertEqual(blocks.count, 1)
        XCTAssertEqual(blocks[0].lines.count, 2)
    }

    func testSameRowLabelsStaySeparate() {
        let lines = [
            line("推荐", x: 100, y: 100, w: 80),
            line("关注", x: 300, y: 100, w: 80),
            line("热门", x: 500, y: 102, w: 80),
        ]
        XCTAssertEqual(grouper.group(lines).count, 3)
    }

    func testCenteredLinesMerge() {
        let lines = [
            line("Welcome back to the app, we", x: 200, y: 100, w: 600),
            line("missed you so much", x: 300, y: 148, w: 400),
        ]
        XCTAssertEqual(grouper.group(lines).count, 1)
    }

    func testTwoBubblesInterleavedStaySeparate() {
        // Chat: left bubble, then right bubble, then left bubble again.
        let lines = [
            line("你在干嘛呢今天有空吗我们出去", x: 40, y: 100, w: 600),
            line("好啊我们去哪里玩比较好呢你说", x: 400, y: 260, w: 600),
            line("去看电影吧最近有部新片很好看", x: 40, y: 420, w: 600),
        ]
        XCTAssertEqual(grouper.group(lines).count, 3)
    }

    func testLatinLinesJoinWithSpace() {
        XCTAssertEqual(TextJoiner.join(["Hello there", "my friend"]), "Hello there my friend")
        XCTAssertEqual(TextJoiner.join(["你好", "朋友"]), "你好朋友")
        XCTAssertEqual(TextJoiner.join(["안녕하세요", "반가워요"]), "안녕하세요 반가워요")
    }

    func testIsShort() {
        XCTAssertTrue(LayoutGrouper.isShort("关注"))
        XCTAssertTrue(LayoutGrouper.isShort("Follow"))
        XCTAssertTrue(LayoutGrouper.isShort("팔로우"))
        XCTAssertFalse(LayoutGrouper.isShort("今天天气很好"))
        XCTAssertFalse(LayoutGrouper.isShort("This is a longer sentence"))
    }
}
