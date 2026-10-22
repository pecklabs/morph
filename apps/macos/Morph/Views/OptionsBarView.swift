import SwiftUI

struct OptionsBarView: View {
    @Environment(AppModel.self) private var model
    @Environment(Localizer.self) private var loc

    var body: some View {
        @Bindable var model = model

        VStack(spacing: 10) {
            // Convert mode keeps a dedicated options row for quality/resize/dpi.
            if model.mode == .convert && !model.jobs.isEmpty {
                HStack(alignment: .center, spacing: 18) {
                    if model.hasImageTargets {
                        qualityControl($model.options.imageQuality)
                        resizeControl(model: $model)
                    }
                    if model.hasPdfToImage {
                        dpiControl($model.options.pdfDPI)
                    }
                    Spacer(minLength: 0)
                    destinationControl
                }
                .font(.callout)
            }

            HStack(spacing: 12) {
                if model.mode == .makePDF {
                    // Single compact row: status + Finder on the left, destination
                    // and the primary action on the right — no extra row.
                    statusSummary
                    makePDFReveal
                    Spacer()
                    if !model.jobs.isEmpty {
                        destinationControl.font(.callout)
                    }
                    makePDFCreate
                } else {
                    statusSummary
                    Spacer()
                    convertActions
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(.bar)
    }

    // MARK: - Actions per mode

    @ViewBuilder
    private var convertActions: some View {
        if doneCount > 0 {
            Button {
                model.revealAllOutputs()
            } label: {
                Label(loc.t("action.showInFinder"), systemImage: "folder")
            }
            .controlSize(.large)
            .secondaryActionStyle()
            .disabled(model.isConverting)
        }

        if model.convertSingleJob != nil {
            Button {
                Task { await model.exportConvertSingle() }
            } label: {
                HStack(spacing: 6) {
                    if model.isConverting { ProgressView().controlSize(.small) }
                    Text(loc.t("action.export")).padding(.horizontal, 4)
                }
            }
            .keyboardShortcut(.return, modifiers: .command)
            .controlSize(.large)
            .primaryActionStyle(tint: Theme.accent)
            .disabled(model.isConverting)
        } else {
            Button {
                Task { await model.convertAll() }
            } label: {
                HStack(spacing: 6) {
                    if model.isConverting { ProgressView().controlSize(.small) }
                    Text(convertButtonTitle).padding(.horizontal, 4)
                }
            }
            .keyboardShortcut(.return, modifiers: .command)
            .controlSize(.large)
            .primaryActionStyle(tint: Theme.accent)
            .disabled(!model.canConvert)
        }
    }

    @ViewBuilder
    private var makePDFReveal: some View {
        if model.combinedOutput != nil {
            Button {
                model.revealCombined()
            } label: {
                Label(loc.t("action.showInFinder"), systemImage: "folder")
            }
            .controlSize(.large)
            .secondaryActionStyle()
            .disabled(model.isConverting)
        }
    }

    private var makePDFCreate: some View {
        Button {
            Task { await model.exportPDF() }
        } label: {
            HStack(spacing: 6) {
                if model.isConverting { ProgressView().controlSize(.small) }
                Text(loc.t("action.createPDF")).padding(.horizontal, 4)
            }
        }
        .keyboardShortcut(.return, modifiers: .command)
        .controlSize(.large)
        .primaryActionStyle(tint: Theme.accent)
        .disabled(!model.canCreatePDF)
    }

    // MARK: - Controls

    private var destinationControl: some View {
        Menu {
            Button {
                model.useOriginalFolder()
            } label: {
                if model.options.outputDirectory == nil {
                    Label(loc.t("dest.sameFolder"), systemImage: "checkmark")
                } else {
                    Text(loc.t("dest.sameFolder"))
                }
            }
            Button(loc.t("dest.choose")) {
                model.chooseOutputFolder()
            }
            if let dir = model.options.outputDirectory {
                Divider()
                Button(loc.f("dest.reveal", dir.lastPathComponent)) {
                    NSWorkspace.shared.activateFileViewerSelecting([dir])
                }
            }
        } label: {
            Label {
                Text(destinationLabel).lineLimit(1)
            } icon: {
                Image(systemName: model.options.outputDirectory == nil ? "folder" : "folder.fill")
            }
        }
        .menuStyle(.borderlessButton)
        .fixedSize()
        .help(loc.t("dest.help"))
        .disabled(model.isConverting)
    }

    private var destinationLabel: String {
        model.options.outputDirectory?.lastPathComponent ?? loc.t("dest.sameFolder")
    }

    private func qualityControl(_ value: Binding<Double>) -> some View {
        HStack(spacing: 6) {
            Text(loc.t("opt.quality"))
                .foregroundStyle(.secondary)
            Slider(value: value, in: 0.1...1.0)
                .frame(width: 110)
            Text("\(Int(value.wrappedValue * 100))%")
                .monospacedDigit()
                .foregroundStyle(.secondary)
                .frame(width: 38, alignment: .trailing)
        }
        .help(loc.t("opt.quality.help"))
    }

    private func resizeControl(model: Bindable<AppModel>) -> some View {
        HStack(spacing: 6) {
            Toggle(loc.t("opt.resize"), isOn: model.options.resizeEnabled)
            if model.wrappedValue.options.resizeEnabled {
                TextField("", value: model.options.maxDimension, format: .number)
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 60)
                    .multilineTextAlignment(.trailing)
                Text(loc.t("opt.pxMax"))
                    .foregroundStyle(.secondary)
            }
        }
        .help(loc.t("opt.resize.help"))
    }

    private func dpiControl(_ value: Binding<Int>) -> some View {
        HStack(spacing: 6) {
            Text(loc.t("opt.pdfDpi"))
                .foregroundStyle(.secondary)
            TextField("", value: value, format: .number)
                .textFieldStyle(.roundedBorder)
                .frame(width: 56)
                .multilineTextAlignment(.trailing)
        }
        .help(loc.t("opt.pdfDpi.help"))
    }

    // MARK: - Summary

    private var convertButtonTitle: String {
        if model.isConverting { return loc.t("action.converting") }
        let n = model.convertibleJobs.count
        return loc.f(n == 1 ? "action.convert.one" : "action.convert.many", n)
    }

    private var doneCount: Int {
        model.jobs.filter { if case .done = $0.status { return true }; return false }.count
    }

    private var failedCount: Int {
        model.jobs.filter { if case .failed = $0.status { return true }; return false }.count
    }

    @ViewBuilder
    private var statusSummary: some View {
        if model.jobs.isEmpty {
            EmptyView()
        } else if model.mode == .makePDF {
            let n = model.combinableJobs.count
            Text(loc.f(n == 1 ? "status.ready.one" : "status.ready.many", n))
                .font(.caption)
                .foregroundStyle(.secondary)
        } else if doneCount > 0 || failedCount > 0 {
            HStack(spacing: 10) {
                if doneCount > 0 {
                    Label(loc.f("status.done", doneCount), systemImage: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                }
                if failedCount > 0 {
                    Label(loc.f("status.failed", failedCount), systemImage: "exclamationmark.triangle.fill")
                        .foregroundStyle(.red)
                }
            }
            .font(.caption)
        } else {
            Text(loc.f(model.jobs.count == 1 ? "status.ready.one" : "status.ready.many", model.jobs.count))
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }
}
