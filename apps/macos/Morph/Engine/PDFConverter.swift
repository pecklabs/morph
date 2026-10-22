import Foundation
import PDFKit
import AppKit
import CoreGraphics
import ImageIO
import UniformTypeIdentifiers

/// PDF <-> image conversion backed by PDFKit and Core Graphics.
enum PDFConverter {

    /// Wraps a single raster image into a one-page PDF.
    static func imageToPDF(input: URL, destination: URL? = nil, outputURL: URL? = nil) throws -> URL {
        guard let source = CGImageSourceCreateWithURL(input as CFURL, nil),
              let cg = CGImageSourceCreateImageAtIndex(source, 0, nil)
        else {
            throw ConversionError.cannotReadImage
        }

        let nsImage = NSImage(cgImage: cg, size: NSSize(width: cg.width, height: cg.height))
        guard let page = PDFPage(image: nsImage) else {
            throw ConversionError.encodeFailed
        }

        let document = PDFDocument()
        document.insert(page, at: 0)

        let outURL = outputURL ?? OutputPath.make(for: input, ext: "pdf", in: destination)
        OutputPath.ensureParent(of: outURL)
        guard document.write(to: outURL) else {
            throw ConversionError.encodeFailed
        }
        return outURL
    }

    /// Merges several files (images and/or existing PDFs) into one PDF, in the given
    /// order. Images become one page each; PDFs contribute all their pages. Other
    /// file types are skipped. Output is "Combined.pdf" next to the first input (or
    /// in `destination`).
    static func combineToPDF(inputs: [URL], destination: URL? = nil, outputURL: URL? = nil) throws -> URL {
        guard let first = inputs.first else { throw ConversionError.emptyInput }
        let document = PDFDocument()
        var index = 0

        for input in inputs {
            let ext = input.pathExtension.lowercased()
            if ext == "pdf" {
                guard let source = PDFDocument(url: input) else { continue }
                for p in 0..<source.pageCount {
                    if let page = source.page(at: p)?.copy() as? PDFPage {
                        document.insert(page, at: index)
                        index += 1
                    }
                }
            } else if Catalog.imageInputs.contains(ext) {
                guard let imageSource = CGImageSourceCreateWithURL(input as CFURL, nil),
                      let cg = CGImageSourceCreateImageAtIndex(imageSource, 0, nil) else { continue }
                let nsImage = NSImage(cgImage: cg, size: NSSize(width: cg.width, height: cg.height))
                if let page = PDFPage(image: nsImage) {
                    document.insert(page, at: index)
                    index += 1
                }
            }
        }

        guard index > 0 else { throw ConversionError.cannotReadImage }

        let anchor = (destination ?? first.deletingLastPathComponent())
            .appendingPathComponent("Combined.pdf")
        let outURL = outputURL ?? OutputPath.make(for: anchor, ext: "pdf", in: destination)
        OutputPath.ensureParent(of: outURL)
        guard document.write(to: outURL) else {
            throw ConversionError.encodeFailed
        }
        return outURL
    }

    /// Renders every PDF page to a raster image at the given DPI. One file per page.
    static func pdfToImages(input: URL, toExt ext: String, dpi: Int, destination: URL? = nil) throws -> [URL] {
        guard let document = PDFDocument(url: input) else {
            throw ConversionError.pdfLoadFailed
        }
        guard document.pageCount > 0 else { throw ConversionError.pdfEmpty }

        guard let outType = ImageConverter.utType(forExt: ext) else {
            throw ConversionError.unsupportedTarget(ext)
        }

        let scale = CGFloat(dpi) / 72.0
        var outputs: [URL] = []

        for i in 0..<document.pageCount {
            guard let page = document.page(at: i), let pageRef = page.pageRef else { continue }

            let bounds = page.bounds(for: .mediaBox)
            let pxW = max(1, Int((bounds.width * scale).rounded()))
            let pxH = max(1, Int((bounds.height * scale).rounded()))

            let colorSpace = CGColorSpace(name: CGColorSpace.sRGB) ?? CGColorSpaceCreateDeviceRGB()
            guard let ctx = CGContext(
                data: nil,
                width: pxW,
                height: pxH,
                bitsPerComponent: 8,
                bytesPerRow: 0,
                space: colorSpace,
                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
            ) else {
                throw ConversionError.cannotCreateContext
            }

            // White background (PDFs are usually drawn on white paper).
            ctx.setFillColor(red: 1, green: 1, blue: 1, alpha: 1)
            ctx.fill(CGRect(x: 0, y: 0, width: pxW, height: pxH))

            ctx.scaleBy(x: scale, y: scale)
            ctx.translateBy(x: -bounds.origin.x, y: -bounds.origin.y)
            ctx.drawPDFPage(pageRef)

            guard let cg = ctx.makeImage() else { throw ConversionError.encodeFailed }

            let suffix = document.pageCount > 1 ? "-\(i + 1)" : ""
            let outURL = OutputPath.make(for: input, ext: ext, suffix: suffix, in: destination)
            guard let dest = CGImageDestinationCreateWithURL(
                outURL as CFURL, outType.identifier as CFString, 1, nil) else {
                throw ConversionError.encodeFailed
            }
            CGImageDestinationAddImage(dest, cg, [
                kCGImageDestinationLossyCompressionQuality: 0.9
            ] as CFDictionary)
            guard CGImageDestinationFinalize(dest) else { throw ConversionError.encodeFailed }
            outputs.append(outURL)
        }

        guard !outputs.isEmpty else { throw ConversionError.pdfEmpty }
        return outputs
    }
}
