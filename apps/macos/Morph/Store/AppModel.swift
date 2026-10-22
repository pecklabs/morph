import Foundation
import AppKit
import Observation
import UniformTypeIdentifiers

/// Top-level task the window is showing.
enum AppMode: String, CaseIterable, Identifiable {
    case convert
    case makePDF
    var id: String { rawValue }
}

@MainActor
@Observable
final class AppModel {
    /// Each tab keeps its own file list so the two tasks don't bleed into each other.
    private var convertJobs: [ConversionJob] = []
    private var pdfJobs: [ConversionJob] = []

    /// The list for the current tab. Reads/writes route to the active mode's storage.
    var jobs: [ConversionJob] {
        get { mode == .makePDF ? pdfJobs : convertJobs }
        set { if mode == .makePDF { pdfJobs = newValue } else { convertJobs = newValue } }
    }

    var options = ConvertOptions()
    var isConverting = false
    var mode: AppMode = .convert

    // MARK: - Intake

    func addFiles(_ urls: [URL]) {
        for url in urls {
            if url.hasDirectoryPath {
                if let items = try? FileManager.default.contentsOfDirectory(
                    at: url, includingPropertiesForKeys: nil, options: [.skipsHiddenFiles]) {
                    for item in items where !item.hasDirectoryPath {
                        appendJob(item)
                    }
                }
            } else {
                appendJob(url)
            }
        }
    }

    private func appendJob(_ url: URL) {
        guard !jobs.contains(where: { $0.url == url }) else { return }
        jobs.append(ConversionJob(url: url))
    }

    func chooseOutputFolder() {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.allowsMultipleSelection = false
        panel.canCreateDirectories = true
        panel.prompt = Localizer.shared.t("panel.chooseFolder.prompt")
        panel.message = Localizer.shared.t("panel.chooseFolder.message")
        if panel.runModal() == .OK, let url = panel.url {
            options.outputDirectory = url
        }
    }

    func useOriginalFolder() {
        options.outputDirectory = nil
    }

    var outputDestinationLabel: String {
        options.outputDirectory?.lastPathComponent ?? "Same folder as original"
    }

    func presentOpenPanel() {
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = true
        panel.canChooseDirectories = true
        panel.canChooseFiles = true
        panel.message = Localizer.shared.t("panel.addFiles.message")
        if panel.runModal() == .OK {
            addFiles(panel.urls)
        }
    }

    func remove(_ job: ConversionJob) { jobs.removeAll { $0.id == job.id } }
    func clear() { jobs.removeAll() }

    /// Reorder the list — convert order and PDF combine order both follow this.
    func move(from source: IndexSet, to destination: Int) {
        jobs.move(fromOffsets: source, toOffset: destination)
    }

    // MARK: - Derived state

    var convertibleJobs: [ConversionJob] { jobs.filter { $0.isConvertible } }
    var canConvert: Bool { !isConverting && !convertibleJobs.isEmpty }

    /// Files that can become PDF pages (images + existing PDFs).
    var combinableJobs: [ConversionJob] {
        jobs.filter { $0.category == .image || $0.category == .document }
    }
    var canCombine: Bool { !isConverting && combinableJobs.count >= 2 }
    /// Make-PDF needs at least one combinable file (a single image → 1-page PDF is fine).
    var canCreatePDF: Bool { !isConverting && !combinableJobs.isEmpty }

    var combinedOutput: URL?
    var errorMessage: String?

    func revealCombined() {
        guard let out = combinedOutput else { return }
        NSWorkspace.shared.activateFileViewerSelecting([out])
    }

    // MARK: - Export with a chosen filename (single output)

    /// The one job to "Export…" when convert mode has exactly one output file.
    var convertSingleJob: ConversionJob? {
        guard mode == .convert else { return nil }
        let items = convertibleJobs
        guard items.count == 1, let job = items.first, let target = job.target else { return nil }
        // pdf -> images can produce many files, so it uses the folder flow instead.
        guard target.operation != .pdfToImages else { return nil }
        return job
    }

    func exportConvertSingle() async {
        guard !isConverting, let job = convertSingleJob, let target = job.target else { return }
        let suggested = job.url.deletingPathExtension().lastPathComponent + "." + target.ext
        guard let url = presentSavePanel(suggestedName: suggested, ext: target.ext) else { return }

        isConverting = true
        defer { isConverting = false }
        job.status = .running
        job.outputs = []

        let input = job.url
        let opts = options
        do {
            let outputs = try await Task.detached(priority: .userInitiated) {
                try ConversionEngine.run(input: input, target: target, options: opts, explicitOutput: url)
            }.value
            job.outputs = outputs
            job.status = .done
            NSWorkspace.shared.activateFileViewerSelecting(outputs)
        } catch {
            job.status = .failed(error.localizedDescription)
        }
    }

    func exportPDF() async {
        guard !isConverting else { return }
        let inputs = combinableJobs.map(\.url)
        guard !inputs.isEmpty else { return }
        guard let url = presentSavePanel(suggestedName: "Combined.pdf", ext: "pdf") else { return }

        isConverting = true
        defer { isConverting = false }
        do {
            let out = try await Task.detached(priority: .userInitiated) {
                try PDFConverter.combineToPDF(inputs: inputs, outputURL: url)
            }.value
            combinedOutput = out
            NSWorkspace.shared.activateFileViewerSelecting([out])
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func presentSavePanel(suggestedName: String, ext: String) -> URL? {
        let panel = NSSavePanel()
        panel.nameFieldStringValue = suggestedName
        if let ut = UTType(filenameExtension: ext) {
            panel.allowedContentTypes = [ut]
        }
        panel.canCreateDirectories = true
        panel.directoryURL = options.outputDirectory
        panel.message = Localizer.shared.t("panel.export.message")
        return panel.runModal() == .OK ? panel.url : nil
    }
    var hasImageTargets: Bool {
        jobs.contains { ($0.target?.operation == .image) || ($0.target?.operation == .imageToPdf) }
    }
    var hasPdfToImage: Bool { jobs.contains { $0.target?.operation == .pdfToImages } }

    // MARK: - Run

    func convertAll() async {
        guard !isConverting else { return }
        isConverting = true
        defer { isConverting = false }

        for job in jobs {
            guard let target = job.target, job.isConvertible else {
                job.status = .skipped("No conversion available")
                continue
            }
            job.status = .running
            job.outputs = []

            let input = job.url
            let opts = options
            do {
                let outputs = try await Task.detached(priority: .userInitiated) {
                    try ConversionEngine.run(input: input, target: target, options: opts)
                }.value
                job.outputs = outputs
                job.status = .done
            } catch {
                job.status = .failed(error.localizedDescription)
            }
        }
    }

    func combineToPDF() async {
        guard !isConverting else { return }
        let inputs = combinableJobs.map(\.url)
        guard inputs.count >= 1 else { return }

        isConverting = true
        defer { isConverting = false }

        let dest = options.outputDirectory
        do {
            let out = try await Task.detached(priority: .userInitiated) {
                try PDFConverter.combineToPDF(inputs: inputs, destination: dest)
            }.value
            combinedOutput = out
            NSWorkspace.shared.activateFileViewerSelecting([out])
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    // MARK: - Finder

    func revealOutputs(_ job: ConversionJob) {
        guard !job.outputs.isEmpty else { return }
        NSWorkspace.shared.activateFileViewerSelecting(job.outputs)
    }

    func revealAllOutputs() {
        let all = jobs.flatMap(\.outputs)
        guard !all.isEmpty else { return }
        NSWorkspace.shared.activateFileViewerSelecting(all)
    }
}
