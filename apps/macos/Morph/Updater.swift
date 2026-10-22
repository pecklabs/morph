import SwiftUI
import Sparkle

/// Owns the Sparkle updater. The controller starts the updater on init, which
/// (with SUEnableAutomaticChecks) checks for updates in the background and,
/// on first launch, asks the user whether automatic checks are OK.
@MainActor
final class UpdaterViewModel: ObservableObject {
    private let controller: SPUStandardUpdaterController
    @Published var canCheckForUpdates = false

    init() {
        controller = SPUStandardUpdaterController(
            startingUpdater: true,
            updaterDelegate: nil,
            userDriverDelegate: nil
        )
        controller.updater.publisher(for: \.canCheckForUpdates)
            .assign(to: &$canCheckForUpdates)
    }

    func checkForUpdates() {
        controller.updater.checkForUpdates()
    }
}

/// The "Check for Updates…" item, placed in the app menu.
struct CheckForUpdatesCommand: View {
    @ObservedObject var updater: UpdaterViewModel
    let title: String

    var body: some View {
        Button(title) { updater.checkForUpdates() }
            .disabled(!updater.canCheckForUpdates)
    }
}
