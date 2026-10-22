import SwiftUI
import AppKit

struct JobRowView: View {
    @Environment(AppModel.self) private var model
    @Environment(Localizer.self) private var loc
    @Bindable var job: ConversionJob
    @State private var hovering = false

    var body: some View {
        HStack(spacing: 12) {
            ThumbnailView(url: job.url, side: 40)

            VStack(alignment: .leading, spacing: 2) {
                Text(job.fileName)
                    .font(.body.weight(.medium))
                    .lineLimit(1)
                    .truncationMode(.middle)
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer(minLength: 8)

            if model.mode == .makePDF {
                makePDFTrailing
            } else {
                convertTrailing
            }

            Button {
                model.remove(job)
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .foregroundStyle(.tertiary)
            }
            .buttonStyle(.plain)
            .opacity(hovering ? 1 : 0)
            .disabled(model.isConverting)
        }
        .opacity(rowDimmed ? 0.5 : 1)
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(Color(nsColor: .controlBackgroundColor))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .strokeBorder(Color.primary.opacity(0.06))
        )
        .onHover { hovering = $0 }
    }

    private var isCombinable: Bool { job.category == .image || job.category == .document }
    private var rowDimmed: Bool { model.mode == .makePDF && !isCombinable }

    @ViewBuilder
    private var convertTrailing: some View {
        if job.isConvertible {
            Image(systemName: "arrow.right")
                .font(.caption.weight(.bold))
                .foregroundStyle(.tertiary)
            formatPicker
        } else {
            Text(loc.t("job.unsupported"))
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        statusView
            .frame(width: 34, alignment: .center)
    }

    @ViewBuilder
    private var makePDFTrailing: some View {
        if !isCombinable {
            Text(loc.t("makepdf.excluded"))
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private var subtitle: String {
        var parts: [String] = [job.inputExt.uppercased()]
        if let size = fileSize { parts.append(size) }
        return parts.joined(separator: " · ")
    }

    private var fileSize: String? {
        guard let values = try? job.url.resourceValues(forKeys: [.fileSizeKey]),
              let bytes = values.fileSize else { return nil }
        return ByteCountFormatter.string(fromByteCount: Int64(bytes), countStyle: .file)
    }

    private var formatPicker: some View {
        Picker("", selection: $job.target) {
            ForEach(job.availableTargets) { target in
                Text(target.label).tag(Optional(target))
            }
        }
        .labelsHidden()
        .frame(width: 128)
        .disabled(model.isConverting)
    }

    @ViewBuilder
    private var statusView: some View {
        switch job.status {
        case .pending:
            Color.clear
        case .running:
            ProgressView().controlSize(.small)
        case .done:
            Button {
                model.revealOutputs(job)
            } label: {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(.green)
            }
            .buttonStyle(.plain)
            .help(loc.t("job.reveal.help"))
        case .failed(let message):
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(.red)
                .help(message)
        case .skipped(let message):
            Image(systemName: "minus.circle")
                .foregroundStyle(.secondary)
                .help(message)
        }
    }
}
