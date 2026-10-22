import SwiftUI
import AppKit
import UniformTypeIdentifiers

/// Make-PDF preview: a grid of large thumbnails you can drag to reorder.
/// The combine order (and page numbers) follow this layout.
struct PDFGridView: View {
    @Environment(AppModel.self) private var model
    @Environment(Localizer.self) private var loc

    @State private var dragging: ConversionJob?
    @State private var previewJob: ConversionJob?

    private let columns = [GridItem(.adaptive(minimum: 136, maximum: 190), spacing: 16)]

    var body: some View {
        ScrollView {
            LazyVGrid(columns: columns, alignment: .leading, spacing: 16) {
                ForEach(model.jobs) { job in
                    PDFGridCell(job: job, pageNumber: pageNumber(for: job)) {
                        previewJob = job
                    }
                    .opacity(dragging?.id == job.id ? 0.4 : 1)
                    .onDrag {
                        dragging = job
                        return NSItemProvider(object: job.id.uuidString as NSString)
                    }
                    .onDrop(
                        of: [UTType.text],
                        delegate: ReorderDropDelegate(item: job, model: model, dragging: $dragging)
                    )
                }
            }
            .padding(16)
        }
        .sheet(item: $previewJob) { job in
            LargePreviewView(job: job)
        }
    }

    /// 1-based position among the files that will actually become PDF pages.
    private func pageNumber(for job: ConversionJob) -> Int? {
        model.combinableJobs.firstIndex { $0.id == job.id }.map { $0 + 1 }
    }
}

private struct PDFGridCell: View {
    @Environment(AppModel.self) private var model
    @Environment(Localizer.self) private var loc
    let job: ConversionJob
    let pageNumber: Int?
    let onOpen: () -> Void
    @State private var hovering = false

    private var isCombinable: Bool { job.category == .image || job.category == .document }

    var body: some View {
        VStack(spacing: 6) {
            ZStack(alignment: .topTrailing) {
                // Button makes the click reliable even though the cell is draggable.
                Button(action: onOpen) {
                    ThumbnailView(url: job.url, side: 150)
                        .frame(maxWidth: .infinity)
                        .overlay(alignment: .topLeading) {
                            if let pageNumber {
                                Text("\(pageNumber)")
                                    .font(.caption.weight(.bold).monospacedDigit())
                                    .foregroundStyle(.white)
                                    .frame(minWidth: 22, minHeight: 22)
                                    .padding(.horizontal, 4)
                                    .background(Circle().fill(Theme.accent).shadow(radius: 1))
                                    .padding(6)
                            }
                        }
                        .overlay {
                            if !isCombinable {
                                RoundedRectangle(cornerRadius: 7)
                                    .fill(.black.opacity(0.45))
                                    .overlay {
                                        Text(loc.t("makepdf.excluded"))
                                            .font(.caption.weight(.semibold))
                                            .foregroundStyle(.white)
                                            .multilineTextAlignment(.center)
                                            .padding(.horizontal, 6)
                                    }
                            }
                        }
                }
                .buttonStyle(.plain)
                .help(loc.t("preview.open"))

                Button {
                    model.remove(job)
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.title3)
                        .foregroundStyle(.white, .black.opacity(0.45))
                }
                .buttonStyle(.plain)
                .padding(6)
                .opacity(hovering ? 1 : 0)
                .disabled(model.isConverting)
            }

            Text(job.fileName)
                .font(.caption)
                .lineLimit(1)
                .truncationMode(.middle)
                .frame(maxWidth: .infinity)
        }
        .opacity(isCombinable ? 1 : 0.7)
        .onHover { hovering = $0 }
    }
}

/// A large preview shown in a sheet when a thumbnail is clicked.
private struct LargePreviewView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(Localizer.self) private var loc
    let job: ConversionJob

    @State private var image: NSImage?
    @State private var loading = true

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text(job.fileName)
                    .font(.headline)
                    .lineLimit(1)
                    .truncationMode(.middle)
                Spacer()
                Button(loc.t("alert.ok")) { dismiss() }
                    .keyboardShortcut(.defaultAction)
            }
            .padding(12)

            Divider()

            Group {
                if let image {
                    Image(nsImage: image)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .padding(16)
                } else if loading {
                    ProgressView()
                } else {
                    Image(nsImage: NSWorkspace.shared.icon(forFile: job.url.path))
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 120, height: 120)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color(nsColor: .windowBackgroundColor))
        }
        .frame(width: 760, height: 580)
        .task(id: job.url) {
            loading = true
            let url = job.url
            let loaded = await Task.detached(priority: .userInitiated) {
                NSImage(contentsOf: url)
            }.value
            image = loaded
            loading = false
        }
    }
}

/// Live reordering: as a dragged cell hovers over another, swap them in place.
private struct ReorderDropDelegate: DropDelegate {
    let item: ConversionJob
    let model: AppModel
    @Binding var dragging: ConversionJob?

    func dropEntered(info: DropInfo) {
        guard let dragging, dragging.id != item.id,
              let from = model.jobs.firstIndex(where: { $0.id == dragging.id }),
              let to = model.jobs.firstIndex(where: { $0.id == item.id })
        else { return }
        withAnimation(.easeInOut(duration: 0.2)) {
            model.move(from: IndexSet(integer: from), to: to > from ? to + 1 : to)
        }
    }

    func dropUpdated(info: DropInfo) -> DropProposal? {
        DropProposal(operation: .move)
    }

    func performDrop(info: DropInfo) -> Bool {
        dragging = nil
        return true
    }
}
