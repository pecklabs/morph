import Foundation

/// High-level kind of a file, used to group conversions in the UI.
enum FileKind: String, CaseIterable {
    case image
    case document
    case data

    var label: String {
        switch self {
        case .image: return "Image"
        case .document: return "Document"
        case .data: return "Data"
        }
    }
}

/// The concrete operation the engine performs for a conversion.
enum Operation: String {
    case image        // raster image -> raster image (Image I/O)
    case imageToPdf   // raster image -> single-page PDF (PDFKit)
    case pdfToImages  // PDF pages -> raster images (Core Graphics)
    case data         // CSV / TSV / JSON interconversion (Foundation)
}

/// A possible output for a given input file.
struct Target: Hashable, Identifiable {
    let ext: String      // lowercase extension, e.g. "png"
    let label: String    // display label, e.g. "PNG"
    let operation: Operation

    var id: String { "\(operation.rawValue):\(ext)" }
}

/// Single source of truth (mirrors packages/conversion-spec/conversions.json)
/// for what Morph can convert and which operation implements each conversion.
enum Catalog {
    static let imageInputs: Set<String> = ["png", "jpg", "jpeg", "heic", "heif", "tiff", "tif", "gif", "bmp", "webp"]
    static let dataInputs: Set<String> = ["csv", "tsv", "json", "xlsx"]

    /// Image output formats, filtered at runtime to what Image I/O can actually write.
    static let imageOutputCandidates: [(ext: String, label: String)] = [
        ("png", "PNG"),
        ("jpg", "JPEG"),
        ("heic", "HEIC"),
        ("tiff", "TIFF"),
        ("gif", "GIF"),
        ("bmp", "BMP"),
        ("webp", "WebP"),
    ]

    static let dataOutputs: [(ext: String, label: String)] = [
        ("csv", "CSV"),
        ("tsv", "TSV"),
        ("json", "JSON"),
        ("xlsx", "Excel"),
    ]

    static func category(forExt ext: String) -> FileKind? {
        let e = ext.lowercased()
        if imageInputs.contains(e) { return .image }
        if e == "pdf" { return .document }
        if dataInputs.contains(e) { return .data }
        return nil
    }

    /// All targets available for a given input file extension.
    static func targets(forInputExt ext: String) -> [Target] {
        let e = ext.lowercased()
        var out: [Target] = []

        if imageInputs.contains(e) {
            let writable = ImageConverter.writableExtensions
            for cand in imageOutputCandidates where writable.contains(cand.ext) {
                // Don't offer a no-op conversion to the same format.
                if cand.ext == e || (cand.ext == "jpg" && (e == "jpeg")) { continue }
                out.append(Target(ext: cand.ext, label: cand.label, operation: .image))
            }
            out.append(Target(ext: "pdf", label: "PDF", operation: .imageToPdf))
        } else if e == "pdf" {
            out.append(Target(ext: "png", label: "PNG (pages)", operation: .pdfToImages))
            out.append(Target(ext: "jpg", label: "JPEG (pages)", operation: .pdfToImages))
        } else if dataInputs.contains(e) {
            for cand in dataOutputs where cand.ext != e {
                out.append(Target(ext: cand.ext, label: cand.label, operation: .data))
            }
        }

        return out
    }
}
