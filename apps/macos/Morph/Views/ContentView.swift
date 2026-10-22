import SwiftUI
import UniformTypeIdentifiers

struct ContentView: View {
    @Environment(AppModel.self) private var model
    @Environment(Localizer.self) private var loc
    @State private var isDropTargeted = false

    var body: some View {
        @Bindable var model = model

        VStack(spacing: 0) {
            Picker("", selection: $model.mode) {
                Text(loc.t("mode.convert")).tag(AppMode.convert)
                Text(loc.t("mode.makePDF")).tag(AppMode.makePDF)
            }
            .pickerStyle(.segmented)
            .labelsHidden()
            .fixedSize()
            .frame(maxWidth: .infinity)
            .padding(.vertical, 8)
            .tint(Theme.accent)
            .disabled(model.isConverting)

            if model.jobs.isEmpty {
                DropZoneView(isTargeted: isDropTargeted)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                filledContent
            }

            Divider()
            OptionsBarView()
        }
        .background(.background)
        .dropDestination(for: URL.self) { urls, _ in
            model.addFiles(urls)
            return !urls.isEmpty
        } isTargeted: { targeted in
            isDropTargeted = targeted
        }
        .overlay {
            if isDropTargeted && !model.jobs.isEmpty {
                dropOverlay
            }
        }
        .toolbar {
            ToolbarItemGroup(placement: .primaryAction) {
                Button {
                    model.presentOpenPanel()
                } label: {
                    Label(loc.t("action.addFiles"), systemImage: "plus")
                }
                .help(loc.t("action.addFiles.help"))

                Button(role: .destructive) {
                    model.clear()
                } label: {
                    Label(loc.t("action.clear"), systemImage: "trash")
                }
                .disabled(model.jobs.isEmpty || model.isConverting)
                .help(loc.t("action.clear.help"))
            }
        }
        .navigationTitle("Morph")
        .alert(
            loc.t("alert.failed.title"),
            isPresented: Binding(
                get: { model.errorMessage != nil },
                set: { if !$0 { model.errorMessage = nil } }
            )
        ) {
            Button(loc.t("alert.ok"), role: .cancel) {}
        } message: {
            Text(model.errorMessage ?? "")
        }
    }

    @ViewBuilder
    private var filledContent: some View {
        if model.mode == .makePDF {
            PDFGridView()
        } else {
            jobList
        }
    }

    private var jobList: some View {
        List {
            ForEach(model.jobs) { job in
                JobRowView(job: job)
                    .listRowSeparator(.hidden)
                    .listRowInsets(EdgeInsets(top: 4, leading: 12, bottom: 4, trailing: 12))
                    .listRowBackground(Color.clear)
            }
            .onMove { from, to in
                model.move(from: from, to: to)
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
    }

    private var dropOverlay: some View {
        ZStack {
            Theme.accent.opacity(0.08)
            RoundedRectangle(cornerRadius: 16)
                .strokeBorder(Theme.accent, style: StrokeStyle(lineWidth: 2, dash: [8, 6]))
                .padding(10)
            Label(loc.t("drop.overlay"), systemImage: "tray.and.arrow.down.fill")
                .font(.title2.weight(.semibold))
                .foregroundStyle(Theme.accentDeep)
        }
        .allowsHitTesting(false)
    }
}
