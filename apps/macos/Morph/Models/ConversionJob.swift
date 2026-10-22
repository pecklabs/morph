import Foundation
import Observation

enum JobStatus: Equatable {
    case pending
    case running
    case done
    case failed(String)
    case skipped(String)
}

/// One input file plus the user's chosen output target and its running state.
@Observable
final class ConversionJob: Identifiable {
    let id = UUID()
    let url: URL
    let inputExt: String
    let category: FileKind?
    let availableTargets: [Target]

    var target: Target?
    var status: JobStatus = .pending
    /// Primary output (first file produced). Multi-file ops store all in `outputs`.
    var outputs: [URL] = []

    init(url: URL) {
        self.url = url
        self.inputExt = url.pathExtension.lowercased()
        self.category = Catalog.category(forExt: inputExt)
        self.availableTargets = Catalog.targets(forInputExt: inputExt)
        self.target = availableTargets.first
    }

    var fileName: String { url.lastPathComponent }
    var isConvertible: Bool { !availableTargets.isEmpty && target != nil }
    var primaryOutput: URL? { outputs.first }
}

/// User-tunable conversion options, shared across all jobs in a batch.
@Observable
final class ConvertOptions {
    /// 0.0...1.0 lossy quality for JPEG / HEIC / WebP.
    var imageQuality: Double = 0.9
    /// When enabled, the longest edge is clamped to `maxDimension` px.
    var resizeEnabled: Bool = false
    var maxDimension: Int = 2048
    /// Render resolution for PDF -> image.
    var pdfDPI: Int = 144

    /// Where converted files are written. `nil` = next to each original file.
    var outputDirectory: URL? = nil

    var effectiveMaxDimension: Int? { resizeEnabled ? maxDimension : nil }
}
