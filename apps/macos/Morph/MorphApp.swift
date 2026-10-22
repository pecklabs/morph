import SwiftUI

@main
struct MorphApp: App {
    @State private var model = AppModel()
    @State private var localizer = Localizer.shared
    @StateObject private var updater = UpdaterViewModel()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(model)
                .environment(localizer)
                .frame(minWidth: 540, minHeight: 460)
        }
        .defaultSize(width: 820, height: 700)
        .windowToolbarStyle(.unified(showsTitle: true))
        .commands {
            CommandGroup(after: .appInfo) {
                CheckForUpdatesCommand(updater: updater, title: localizer.t("action.checkForUpdates"))
            }
            CommandGroup(after: .newItem) {
                Button(localizer.t("action.addFiles.menu")) { model.presentOpenPanel() }
                    .keyboardShortcut("o", modifiers: .command)
            }
        }

        Settings {
            SettingsView()
                .environment(localizer)
        }
    }
}
