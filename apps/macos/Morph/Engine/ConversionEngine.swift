import Foundation

/// Routes a job to the right converter. Pure/synchronous and thread-safe to call
/// off the main actor; callers run it inside a detached task.
enum ConversionEngine {
    static func run(input: URL, target: Target, options: ConvertOptions, explicitOutput: URL? = nil) throws -> [URL] {
        let dest = options.outputDirectory
        switch target.operation {
        case .image:
            let out = try ImageConverter.convert(
                input: input,
                toExt: target.ext,
                quality: options.imageQuality,
                maxDimension: options.effectiveMaxDimension,
                destination: dest,
                outputURL: explicitOutput
            )
            return [out]

        case .imageToPdf:
            return [try PDFConverter.imageToPDF(input: input, destination: dest, outputURL: explicitOutput)]

        case .pdfToImages:
            // Multiple files out — an explicit single name doesn't apply.
            return try PDFConverter.pdfToImages(input: input, toExt: target.ext, dpi: options.pdfDPI, destination: dest)

        case .data:
            return [try DataConverter.convert(input: input, toExt: target.ext, destination: dest, outputURL: explicitOutput)]
        }
    }
}
