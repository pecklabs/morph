import Foundation
import ImageIO
import CoreGraphics
import UniformTypeIdentifiers

/// Raster image conversion backed by Image I/O. All work is on-device.
enum ImageConverter {

    /// Maps our friendly extensions to the UTType Image I/O writes.
    static func utType(forExt ext: String) -> UTType? {
        switch ext.lowercased() {
        case "png": return .png
        case "jpg", "jpeg": return .jpeg
        case "heic": return UTType("public.heic") ?? .heic
        case "heif": return UTType("public.heif")
        case "tiff", "tif": return .tiff
        case "gif": return .gif
        case "bmp": return .bmp
        case "webp": return UTType.webP
        default: return nil
        }
    }

    /// Extensions Image I/O can actually encode on this machine, resolved once.
    static let writableExtensions: Set<String> = {
        let ids = Set((CGImageDestinationCopyTypeIdentifiers() as? [String]) ?? [])
        var result = Set<String>()
        for cand in ["png", "jpg", "heic", "tiff", "gif", "bmp", "webp"] {
            if let ut = utType(forExt: cand), ids.contains(ut.identifier) {
                result.insert(cand)
            }
        }
        return result
    }()

    static func convert(input: URL, toExt ext: String, quality: Double, maxDimension: Int?, destination: URL? = nil, outputURL: URL? = nil) throws -> URL {
        guard let outType = utType(forExt: ext) else {
            throw ConversionError.unsupportedTarget(ext)
        }

        guard let source = CGImageSourceCreateWithURL(input as CFURL, nil),
              var image = CGImageSourceCreateImageAtIndex(
                source, 0, [kCGImageSourceShouldCacheImmediately: false] as CFDictionary)
        else {
            throw ConversionError.cannotReadImage
        }

        if let maxDimension, let resized = resize(image, maxDimension: maxDimension) {
            image = resized
        }

        let outURL = outputURL ?? OutputPath.make(for: input, ext: ext, in: destination)
        OutputPath.ensureParent(of: outURL)
        guard let dest = CGImageDestinationCreateWithURL(
            outURL as CFURL, outType.identifier as CFString, 1, nil)
        else {
            throw ConversionError.encodeFailed
        }

        let props: [CFString: Any] = [
            kCGImageDestinationLossyCompressionQuality: quality
        ]
        CGImageDestinationAddImage(dest, image, props as CFDictionary)

        guard CGImageDestinationFinalize(dest) else {
            throw ConversionError.encodeFailed
        }
        return outURL
    }

    /// Scales an image so its longest edge is at most `maxDimension`. Returns the
    /// original if it already fits. Uses sRGB to stay encoder-friendly.
    static func resize(_ image: CGImage, maxDimension: Int) -> CGImage? {
        let w = image.width
        let h = image.height
        let longest = max(w, h)
        guard longest > maxDimension, longest > 0 else { return image }

        let scale = Double(maxDimension) / Double(longest)
        let nw = max(1, Int((Double(w) * scale).rounded()))
        let nh = max(1, Int((Double(h) * scale).rounded()))

        let colorSpace = CGColorSpace(name: CGColorSpace.sRGB) ?? CGColorSpaceCreateDeviceRGB()
        guard let ctx = CGContext(
            data: nil,
            width: nw,
            height: nh,
            bitsPerComponent: 8,
            bytesPerRow: 0,
            space: colorSpace,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else {
            return nil
        }
        ctx.interpolationQuality = .high
        ctx.draw(image, in: CGRect(x: 0, y: 0, width: nw, height: nh))
        return ctx.makeImage()
    }
}
