import Foundation
import Observation

enum AppLanguage: String, CaseIterable, Identifiable {
    case system
    case en
    case ko

    var id: String { rawValue }

    /// Shown in the language picker (native names where it reads better).
    @MainActor
    func displayName(_ loc: Localizer) -> String {
        switch self {
        case .system: return loc.t("settings.language.system")
        case .en: return "English"
        case .ko: return "한국어"
        }
    }
}

/// Live, relaunch-free localization. `.system` follows the OS; `.en` / `.ko` read
/// strings from a fixed `.lproj` bundle. Views observe `language`, so flipping it in
/// Settings updates the whole UI immediately.
@MainActor
@Observable
final class Localizer {
    static let shared = Localizer()

    private static let key = "appLanguage"

    var language: AppLanguage {
        didSet { UserDefaults.standard.set(language.rawValue, forKey: Self.key) }
    }

    init() {
        let raw = UserDefaults.standard.string(forKey: Self.key) ?? AppLanguage.system.rawValue
        self.language = AppLanguage(rawValue: raw) ?? .system
    }

    private func bundle() -> Bundle {
        switch language {
        case .system:
            return .main
        case .en, .ko:
            if let path = Bundle.main.path(forResource: language.rawValue, ofType: "lproj"),
               let b = Bundle(path: path) {
                return b
            }
            return .main
        }
    }

    /// Localized string for `key` (falls back to the key itself if missing).
    func t(_ key: String) -> String {
        bundle().localizedString(forKey: key, value: key, table: nil)
    }

    /// Localized format string filled with `args`.
    func f(_ key: String, _ args: CVarArg...) -> String {
        String(format: t(key), arguments: args)
    }
}
