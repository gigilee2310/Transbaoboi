import CoreGraphics
import Foundation
import ImageIO
import UniformTypeIdentifiers

enum ImageLoader {
    /// Screenshots of current iPhones are under 3000 px tall; bigger photos get downscaled to save memory.
    static let maxPixelSize = 3000

    /// Decodes and (if needed) downscales an image, applying EXIF orientation.
    static func cgImage(from data: Data, maxPixelSize: Int = maxPixelSize) throws -> CGImage {
        guard let source = CGImageSourceCreateWithData(data as CFData, nil) else {
            throw BaoboiiiError.cannotReadImage
        }
        let options: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceThumbnailMaxPixelSize: maxPixelSize,
            kCGImageSourceShouldCacheImmediately: true,
        ]
        guard let image = CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary) else {
            throw BaoboiiiError.cannotReadImage
        }
        return image
    }

    static func scaled(_ image: CGImage, maxPixelSize: Int) -> CGImage {
        let longSide = max(image.width, image.height)
        guard longSide > maxPixelSize else { return image }
        let scale = CGFloat(maxPixelSize) / CGFloat(longSide)
        let w = Int(CGFloat(image.width) * scale), h = Int(CGFloat(image.height) * scale)
        guard let ctx = CGContext(data: nil, width: w, height: h, bitsPerComponent: 8, bytesPerRow: 0,
                                  space: CGColorSpaceCreateDeviceRGB(),
                                  bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue) else { return image }
        ctx.interpolationQuality = .high
        ctx.draw(image, in: CGRect(x: 0, y: 0, width: w, height: h))
        return ctx.makeImage() ?? image
    }

    static func jpegData(_ image: CGImage, quality: CGFloat) -> Data? {
        encode(image, type: .jpeg, options: [kCGImageDestinationLossyCompressionQuality: quality])
    }

    static func pngData(_ image: CGImage) -> Data? {
        encode(image, type: .png, options: [:])
    }

    private static func encode(_ image: CGImage, type: UTType, options: [CFString: Any]) -> Data? {
        let data = NSMutableData()
        guard let dest = CGImageDestinationCreateWithData(data, type.identifier as CFString, 1, nil) else { return nil }
        CGImageDestinationAddImage(dest, image, options as CFDictionary)
        guard CGImageDestinationFinalize(dest) else { return nil }
        return data as Data
    }
}
