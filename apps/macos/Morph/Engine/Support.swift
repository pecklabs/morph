import Foundation

enum ConversionError: LocalizedError {
    case cannotReadImage
    case unsupportedTarget(String)
    case cannotCreateContext
    case encodeFailed
    case pdfLoadFailed
    case pdfEmpty
    case dataParse(String)
    case emptyInput

    var errorDescription: String? {
        switch self {
        case .cannotReadImage: return "Could not read the image file."
        case .unsupportedTarget(let t): return "This system can't write \(t.uppercased()) files."
        case .cannotCreateContext: return "Could not allocate a drawing context."
        case .encodeFailed: return "Failed to encode the output file."
        case .pdfLoadFailed: return "Could not open the PDF."
        case .pdfEmpty: return "The PDF has no pages."
        case .dataParse(let why): return "Could not parse the data file: \(why)"
        case .emptyInput: return "The file is empty."
        }
    }
}

/// Builds a non-colliding output URL. Defaults to the input file's folder; pass
/// `directory` to send output somewhere else (the chosen destination folder).
enum OutputPath {
    static func make(for input: URL, ext: String, suffix: String = "", in directory: URL? = nil) -> URL {
        let dir = directory ?? input.deletingLastPathComponent()
        let base = input.deletingPathExtension().lastPathComponent + suffix
        let fm = FileManager.default

        var candidate = dir.appendingPathComponent(base).appendingPathExtension(ext)
        var n = 2
        while fm.fileExists(atPath: candidate.path) {
            candidate = dir.appendingPathComponent("\(base) \(n)").appendingPathExtension(ext)
            n += 1
        }
        return candidate
    }

    /// Make sure the output's parent folder exists (for an explicitly chosen path).
    static func ensureParent(of url: URL) {
        try? FileManager.default.createDirectory(
            at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
    }
}
