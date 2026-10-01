import UIKit

/// Draws OCR lines (red) and grouped blocks (green; blue for short labels, numbered) on the original image.
enum DebugRenderer {
    static func render(image: CGImage, lines: [OCRLine], blocks: [TextBlock], tags: [Int: String] = [:]) -> UIImage {
        let size = CGSize(width: image.width, height: image.height)
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        format.opaque = true
        let unit = max(2, size.width / 400)

        return UIGraphicsImageRenderer(size: size, format: format).image { ctx in
            UIImage(cgImage: image).draw(in: CGRect(origin: .zero, size: size))
            let cg = ctx.cgContext

            cg.setStrokeColor(UIColor.systemRed.cgColor)
            cg.setLineWidth(unit * 0.6)
            for line in lines { cg.stroke(line.rect) }

            let font = UIFont.monospacedSystemFont(ofSize: unit * 6, weight: .bold)
            for block in blocks {
                let color: UIColor = block.isShortLabel ? .systemBlue : .systemGreen
                cg.setStrokeColor(color.cgColor)
                cg.setLineWidth(unit * 1.2)
                cg.stroke(block.rect.insetBy(dx: -unit * 1.5, dy: -unit * 1.5))

                var label = "#\(block.id)"
                if let tag = tags[block.id] { label += " \(tag)" }
                let attrs: [NSAttributedString.Key: Any] = [
                    .font: font, .foregroundColor: UIColor.white, .backgroundColor: color,
                ]
                let origin = CGPoint(x: max(0, block.rect.minX - unit * 1.5),
                                     y: max(0, block.rect.minY - unit * 1.5 - font.lineHeight))
                (label as NSString).draw(at: origin, withAttributes: attrs)
            }
        }
    }
}
