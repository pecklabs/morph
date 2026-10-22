import SwiftUI

struct SettingsView: View {
    @Environment(Localizer.self) private var loc

    var body: some View {
        @Bindable var loc = loc

        Form {
            Section(loc.t("settings.section.general")) {
                Picker(loc.t("settings.language"), selection: $loc.language) {
                    ForEach(AppLanguage.allCases) { lang in
                        Text(lang.displayName(loc)).tag(lang)
                    }
                }
                Text(loc.t("settings.language.note"))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
        .frame(width: 400, height: 190)
    }
}
