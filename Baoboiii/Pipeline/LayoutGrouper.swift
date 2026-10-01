import CoreGraphics
import Foundation

/// Groups OCR lines into blocks (paragraphs / bubbles) with simple geometric heuristics.
/// Pure Swift, no Vision dependency, so it is unit-testable.
struct LayoutGrouper: Sendable {
    struct Config: Sendable {
        /// Max relative difference between line heights inside a block.
        var heightTolerance: CGFloat = 0.2
        /// Max vertical gap between consecutive lines, as a multiple of line height.
        var maxGapFactor: CGFloat = 0.8
        /// Max horizontal offset of left / center / right edges, as a multiple of line height.
        var alignTolerance: CGFloat = 1.0
    }

    var config = Config()

    init(config: Config = Config()) {
        self.config = config
    }

    /// Short text such as buttons, tabs, counters.
    static func isShort(_ text: String) -> Bool {
        let scalars = text.unicodeScalars.filter { !$0.properties.isWhitespace }
        let cjk = scalars.filter(Script.isCJK).count
        if cjk > 0 { return scalars.count <= 4 }
        return scalars.count <= 12 && text.split(separator: " ").count <= 2
    }

    func group(_ lines: [OCRLine]) -> [TextBlock] {
        let sorted = lines.sorted {
            $0.rect.minY != $1.rect.minY ? $0.rect.minY < $1.rect.minY : $0.rect.minX < $1.rect.minX
        }
        var groups: [[OCRLine]] = []

        for line in sorted {
            var best: (index: Int, gap: CGFloat)?
            for (index, group) in groups.enumerated() {
                guard let last = group.last, canAppend(line, after: last, in: group) else { continue }
                let gap = line.rect.minY - last.rect.maxY
                if best == nil || gap < best!.gap { best = (index, gap) }
            }
            if let best {
                groups[best.index].append(line)
            } else {
                groups.append([line])
            }
        }

        return groups.enumerated().map { TextBlock(id: $0.offset, lines: $0.element) }
    }

    func canAppend(_ line: OCRLine, after last: OCRLine, in group: [OCRLine]) -> Bool {
        let a = last.rect, b = line.rect
        let h = max(a.height, b.height)
        guard h > 0 else { return false }

        // Similar text height.
        guard abs(a.height - b.height) / h < config.heightTolerance else { return false }

        // Next line must be below, close enough.
        let gap = b.minY - a.maxY
        guard b.midY > a.maxY - a.height * 0.2, gap < config.maxGapFactor * h else { return false }

        // Horizontal overlap and a shared alignment (left, center or right).
        let overlap = min(a.maxX, b.maxX) - max(a.minX, b.minX)
        guard overlap > 0 else { return false }
        let tol = config.alignTolerance * h
        let aligned = abs(a.minX - b.minX) < tol || abs(a.midX - b.midX) < tol || abs(a.maxX - b.maxX) < tol
        guard aligned else { return false }

        // Stacks of short labels (button / tab columns) stay separate.
        // A short line may only join as the tail of a paragraph.
        let lastShort = Self.isShort(last.text)
        let lineShort = Self.isShort(line.text)
        if lastShort && lineShort { return false }
        if lastShort && group.count == 1 { return false }

        return true
    }
}
