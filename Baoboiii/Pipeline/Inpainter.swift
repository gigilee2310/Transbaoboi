import CoreGraphics
import Foundation

struct RGB: Equatable, Sendable, Codable {
    var r: UInt8
    var g: UInt8
    var b: UInt8

    static let black = RGB(r: 20, g: 20, b: 20)
    static let white = RGB(r: 255, g: 255, b: 255)

    /// WCAG relative luminance, 0…1.
    var luminance: Double {
        func channel(_ v: UInt8) -> Double {
            let c = Double(v) / 255
            return c <= 0.03928 ? c / 12.92 : pow((c + 0.055) / 1.055, 2.4)
        }
        return 0.2126 * channel(r) + 0.7152 * channel(g) + 0.0722 * channel(b)
    }

    func contrast(with other: RGB) -> Double {
        let a = luminance, b = other.luminance
        return (max(a, b) + 0.05) / (min(a, b) + 0.05)
    }

    func distance(to other: RGB) -> Int {
        abs(Int(r) - Int(other.r)) + abs(Int(g) - Int(other.g)) + abs(Int(b) - Int(other.b))
    }

    /// Readable text color on `background`: this color if contrast is enough, else black or white.
    func readable(on background: RGB) -> RGB {
        if contrast(with: background) >= 3 { return self }
        return background.luminance > 0.4 ? .black : .white
    }
}

struct BlockStyle: Sendable, Equatable, Codable {
    let background: RGB
    let text: RGB
}

/// Removes the original text. The MVP implementation fills each line with the median color
/// sampled just outside it; a real (CoreML) inpainting model can replace it later.
protocol Inpainter: Sendable {
    /// `regions`: line rectangles per block id, pixel coordinates (top-left origin).
    func inpaint(_ image: CGImage, regions: [Int: [CGRect]]) -> (image: CGImage, styles: [Int: BlockStyle])
}

struct MedianFillInpainter: Inpainter {
    static func padding(for rect: CGRect) -> CGFloat {
        max(2, (rect.height * 0.18).rounded())
    }

    func inpaint(_ image: CGImage, regions: [Int: [CGRect]]) -> (image: CGImage, styles: [Int: BlockStyle]) {
        guard let bitmap = Bitmap(image) else { return (image, [:]) }
        let bounds = CGRect(x: 0, y: 0, width: bitmap.width, height: bitmap.height)

        // 1. Measure colors on the untouched image.
        var styles: [Int: BlockStyle] = [:]
        var fills: [(CGRect, RGB)] = []
        for (id, rects) in regions where !rects.isEmpty {
            let padded = rects.map { $0.insetBy(dx: -Self.padding(for: $0), dy: -Self.padding(for: $0)).intersection(bounds) }
                .filter { !$0.isNull && !$0.isEmpty }
            guard !padded.isEmpty else { continue }

            var ring: [RGB] = []
            for rect in padded { bitmap.sampleRing(around: rect, into: &ring) }
            let background = Self.median(ring) ?? .white

            var ink: [RGB] = []
            for rect in rects { bitmap.sampleInside(rect.intersection(bounds), differingFrom: background, into: &ink) }
            let text = (ink.count >= 6 ? Self.median(ink) : nil) ?? (background.luminance > 0.4 ? .black : .white)
            styles[id] = BlockStyle(background: background, text: text.readable(on: background))

            for rect in padded { fills.append((rect, background)) }
            // Close the gaps between consecutive lines of the same block.
            for (a, b) in zip(padded, padded.dropFirst()) {
                let minX = max(a.minX, b.minX), maxX = min(a.maxX, b.maxX)
                if maxX > minX, b.minY > a.maxY {
                    fills.append((CGRect(x: minX, y: a.maxY, width: maxX - minX, height: b.minY - a.maxY), background))
                }
            }
        }

        // 2. Paint.
        for (rect, color) in fills { bitmap.fill(rect, with: color) }
        return (bitmap.makeImage() ?? image, styles)
    }

    static func median(_ colors: [RGB]) -> RGB? {
        guard !colors.isEmpty else { return nil }
        func channelMedian(_ value: (RGB) -> UInt8) -> UInt8 {
            var histogram = [Int](repeating: 0, count: 256)
            for c in colors { histogram[Int(value(c))] += 1 }
            let half = colors.count / 2
            var seen = 0
            for (v, n) in histogram.enumerated() {
                seen += n
                if seen > half { return UInt8(v) }
            }
            return 255
        }
        return RGB(r: channelMedian(\.r), g: channelMedian(\.g), b: channelMedian(\.b))
    }
}

/// RGBA8 bitmap with direct pixel access. Row 0 is the top row of the image.
final class Bitmap {
    let width: Int
    let height: Int
    private let context: CGContext
    private let bytesPerRow: Int
    private let pixels: UnsafeMutablePointer<UInt8>

    init?(_ image: CGImage) {
        width = image.width
        height = image.height
        guard let ctx = CGContext(data: nil, width: width, height: height, bitsPerComponent: 8, bytesPerRow: 0,
                                  space: CGColorSpace(name: CGColorSpace.sRGB) ?? CGColorSpaceCreateDeviceRGB(),
                                  bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue),
              let data = ctx.data else { return nil }
        ctx.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))
        context = ctx
        bytesPerRow = ctx.bytesPerRow
        pixels = data.bindMemory(to: UInt8.self, capacity: bytesPerRow * height)
    }

    func makeImage() -> CGImage? { context.makeImage() }

    @inline(__always)
    func pixel(_ x: Int, _ y: Int) -> RGB {
        let i = y * bytesPerRow + x * 4
        return RGB(r: pixels[i], g: pixels[i + 1], b: pixels[i + 2])
    }

    func fill(_ rect: CGRect, with color: RGB) {
        guard !rect.isNull, !rect.isEmpty, rect.isFinite else { return }
        let x0 = max(0, Int(rect.minX.rounded(.down))), x1 = min(width, Int(rect.maxX.rounded(.up)))
        let y0 = max(0, Int(rect.minY.rounded(.down))), y1 = min(height, Int(rect.maxY.rounded(.up)))
        guard x1 > x0, y1 > y0 else { return }
        for y in y0..<y1 {
            var i = y * bytesPerRow + x0 * 4
            for _ in x0..<x1 {
                pixels[i] = color.r
                pixels[i + 1] = color.g
                pixels[i + 2] = color.b
                pixels[i + 3] = 255
                i += 4
            }
        }
    }

    /// Samples a 3 px thick ring just outside `rect`.
    func sampleRing(around rect: CGRect, into out: inout [RGB]) {
        guard !rect.isNull, !rect.isEmpty, rect.isFinite else { return }
        let x0 = Int(rect.minX) - 1, x1 = Int(rect.maxX)
        let y0 = Int(rect.minY) - 1, y1 = Int(rect.maxY)
        let perimeter = 2 * ((x1 - x0) + (y1 - y0))
        let step = max(1, perimeter / 240)
        for d in 0..<3 {
            var x = x0 - d
            while x <= x1 + d {
                append(x, y0 - d, &out)
                append(x, y1 + d, &out)
                x += step
            }
            var y = y0 - d
            while y <= y1 + d {
                append(x0 - d, y, &out)
                append(x1 + d, y, &out)
                y += step
            }
        }
    }

    /// Samples pixels inside `rect` that clearly differ from the background (the glyphs).
    func sampleInside(_ rect: CGRect, differingFrom background: RGB, into out: inout [RGB]) {
        guard !rect.isNull, !rect.isEmpty, rect.isFinite else { return }
        let step = max(1, Int(rect.height / 16))
        var y = Int(rect.minY)
        while y < Int(rect.maxY) {
            var x = Int(rect.minX)
            while x < Int(rect.maxX) {
                if x >= 0, x < width, y >= 0, y < height {
                    let p = pixel(x, y)
                    if p.distance(to: background) > 120 { out.append(p) }
                }
                x += step
            }
            y += step
        }
    }

    @inline(__always)
    private func append(_ x: Int, _ y: Int, _ out: inout [RGB]) {
        guard x >= 0, x < width, y >= 0, y < height else { return }
        out.append(pixel(x, y))
    }
}

private extension CGRect {
    var isFinite: Bool {
        minX.isFinite && minY.isFinite && maxX.isFinite && maxY.isFinite
    }
}
