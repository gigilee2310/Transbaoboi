import UIKit

struct RenderItem: Sendable {
    let id: Int
    let blockRect: CGRect
    let lineHeight: CGFloat
    let lineCount: Int
    let text: String
    let style: BlockStyle
    let isShortLabel: Bool
    let centered: Bool
}

/// Where and how a translation is drawn.
struct TextLayout: Equatable {
    var frame: CGRect
    var fontSize: CGFloat
    var singleLine: Bool
    var truncated: Bool
}

/// Draws the Vietnamese text into each block, shrinking the font and growing the frame
/// (sideways for single lines, downwards for paragraphs) when needed.
struct TextRenderer: Sendable {
    /// Points → pixels guess: screenshots are ~390 pt wide.
    static func pixelsPerPoint(imageWidth: CGFloat) -> CGFloat {
        max(1, imageWidth / 390)
    }

    func render(base: CGImage, items: [RenderItem], obstacles: [CGRect]) -> (image: UIImage, frames: [Int: CGRect]) {
        let size = CGSize(width: base.width, height: base.height)
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        format.opaque = true
        var frames: [Int: CGRect] = [:]

        let image = UIGraphicsImageRenderer(size: size, format: format).image { _ in
            UIImage(cgImage: base).draw(in: CGRect(origin: .zero, size: size))
            for item in items {
                let others = obstacles.filter { !$0.intersects(item.blockRect.insetBy(dx: 1, dy: 1)) }
                let layout = Self.layout(for: item, imageSize: size, obstacles: others)
                draw(item, layout: layout)
                frames[item.id] = layout.frame
            }
        }
        return (image, frames)
    }

    private func draw(_ item: RenderItem, layout: TextLayout) {
        let background = item.style.background.uiColor
        let original = item.blockRect
        let frame = layout.frame
        let pad = MedianFillInpainter.padding(for: CGRect(x: 0, y: 0, width: 1, height: item.lineHeight))

        // Cover the parts of the frame that grew beyond the original (already inpainted) block.
        background.setFill()
        if frame.maxY > original.maxY {
            UIRectFill(CGRect(x: frame.minX - pad, y: original.maxY, width: frame.width + 2 * pad, height: frame.maxY - original.maxY + pad))
        }
        if frame.minX < original.minX {
            UIRectFill(CGRect(x: frame.minX - pad, y: frame.minY - pad, width: original.minX - frame.minX + pad, height: frame.height + 2 * pad))
        }
        if frame.maxX > original.maxX {
            UIRectFill(CGRect(x: original.maxX, y: frame.minY - pad, width: frame.maxX - original.maxX + pad, height: frame.height + 2 * pad))
        }

        let attributed = Self.attributed(item.text, size: layout.fontSize, color: item.style.text.uiColor,
                                         centered: item.centered || item.isShortLabel, singleLine: layout.singleLine)
        let measured = Self.measure(attributed, width: frame.width)
        var textRect = frame
        if measured.height < frame.height {
            // Vertically center inside the frame.
            textRect.origin.y = frame.midY - measured.height / 2
            textRect.size.height = measured.height + 1
        }
        attributed.draw(with: textRect, options: [.usesLineFragmentOrigin, .usesFontLeading, .truncatesLastVisibleLine], context: nil)
    }

    // MARK: - Layout

    static func layout(for item: RenderItem, imageSize: CGSize, obstacles: [CGRect]) -> TextLayout {
        let r = item.blockRect
        let ppp = pixelsPerPoint(imageWidth: imageSize.width)
        let minFont = 9 * ppp
        let start = max(minFont, item.lineHeight * 0.8)
        let comfortable = max(minFont, start * 0.72)
        let gap = 2 * ppp

        // Free space around the block.
        var minLeft: CGFloat = 0, maxRight = imageSize.width
        var maxBottom = imageSize.height - 1
        for o in obstacles {
            let hOverlap = min(o.maxX, r.maxX) - max(o.minX, r.minX)
            let vOverlap = min(o.maxY, r.maxY) - max(o.minY, r.minY)
            if hOverlap > 0, o.minY >= r.maxY - r.height * 0.2 { maxBottom = min(maxBottom, o.minY - gap) }
            if vOverlap > min(o.height, r.height) * 0.3 {
                if o.maxX <= r.minX + 1 { minLeft = max(minLeft, o.maxX + gap) }
                if o.minX >= r.maxX - 1 { maxRight = min(maxRight, o.minX - gap) }
            }
        }
        maxBottom = max(r.maxY, min(maxBottom, r.maxY + max(r.height * 1.5, item.lineHeight * 3)))
        minLeft = min(minLeft, r.minX)
        maxRight = max(maxRight, r.maxX)

        let centered = item.centered || item.isShortLabel

        // Single line: keep it on one line, widening sideways if there is room.
        if item.lineCount == 1 {
            let maxWidth: CGFloat
            if centered {
                let half = min(r.midX - minLeft, maxRight - r.midX)
                maxWidth = max(r.width, min(2 * half, r.width * 2.2 + item.lineHeight * 2))
            } else {
                maxWidth = max(r.width, min(maxRight - r.minX, r.width * 2.2 + item.lineHeight * 2))
            }
            for size in sizes(from: start, to: comfortable) {
                let width = measure(attributed(item.text, size: size, singleLine: true), width: .greatestFiniteMagnitude).width + 2
                if width <= maxWidth {
                    let w = max(width, r.width)
                    var x = centered ? r.midX - w / 2 : r.minX
                    x = min(max(x, minLeft), max(minLeft, maxRight - w))
                    return TextLayout(frame: CGRect(x: x, y: r.minY, width: w, height: r.height), fontSize: size, singleLine: true, truncated: false)
                }
            }
        }

        // Paragraph: shrink to fit the block, then grow downwards, then shrink to the minimum.
        var width = r.width
        var x = r.minX
        if item.lineCount == 1 {
            // A long single line that did not fit: wrap it, using the widest space available.
            width = centered ? min(r.midX - minLeft, maxRight - r.midX) * 2 : maxRight - r.minX
            width = min(max(width, r.width), r.width * 2.2 + item.lineHeight * 2)
            x = centered ? r.midX - width / 2 : r.minX
        }
        for size in sizes(from: start, to: comfortable) {
            let h = measure(attributed(item.text, size: size, singleLine: false), width: width).height
            if h <= r.height + item.lineHeight * 0.15 {
                return TextLayout(frame: CGRect(x: x, y: r.minY, width: width, height: r.height), fontSize: size, singleLine: false, truncated: false)
            }
        }
        let maxHeight = maxBottom - r.minY
        for size in sizes(from: comfortable, to: minFont) {
            let h = measure(attributed(item.text, size: size, singleLine: false), width: width).height
            if h <= maxHeight {
                return TextLayout(frame: CGRect(x: x, y: r.minY, width: width, height: max(r.height, ceil(h))), fontSize: size, singleLine: false, truncated: false)
            }
        }
        return TextLayout(frame: CGRect(x: x, y: r.minY, width: width, height: maxHeight), fontSize: minFont, singleLine: false, truncated: true)
    }

    static func sizes(from start: CGFloat, to end: CGFloat) -> [CGFloat] {
        var result: [CGFloat] = []
        var s = start
        while s > end {
            result.append(s)
            s *= 0.92
        }
        result.append(end)
        return result
    }

    static func attributed(_ text: String, size: CGFloat, color: UIColor = .black, centered: Bool = false, singleLine: Bool) -> NSAttributedString {
        let paragraph = NSMutableParagraphStyle()
        paragraph.alignment = centered ? .center : .natural
        paragraph.lineBreakMode = singleLine ? .byClipping : .byWordWrapping
        paragraph.lineHeightMultiple = 1.0
        return NSAttributedString(string: text, attributes: [
            .font: UIFont.systemFont(ofSize: size, weight: .medium),
            .foregroundColor: color,
            .paragraphStyle: paragraph,
        ])
    }

    static func measure(_ text: NSAttributedString, width: CGFloat) -> CGSize {
        let rect = text.boundingRect(with: CGSize(width: width, height: .greatestFiniteMagnitude),
                                     options: [.usesLineFragmentOrigin, .usesFontLeading], context: nil)
        return CGSize(width: ceil(rect.width), height: ceil(rect.height))
    }
}

extension RGB {
    var uiColor: UIColor {
        UIColor(red: CGFloat(r) / 255, green: CGFloat(g) / 255, blue: CGFloat(b) / 255, alpha: 1)
    }
}
