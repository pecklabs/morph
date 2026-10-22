import SwiftUI

/// Centralized button looks. Uses Liquid Glass on macOS 26+, and falls back to the
/// classic bordered styles on earlier systems so the app still runs on macOS 14–15.
extension View {
    /// Primary call-to-action (Convert). Prominent + tinted.
    @ViewBuilder
    func primaryActionStyle(tint: Color) -> some View {
        if #available(macOS 26.0, *) {
            self.buttonStyle(.glassProminent).tint(tint)
        } else {
            self.buttonStyle(.borderedProminent).tint(tint)
        }
    }

    /// Secondary action (Show in Finder, Combine, Choose Files).
    @ViewBuilder
    func secondaryActionStyle() -> some View {
        if #available(macOS 26.0, *) {
            self.buttonStyle(.glass)
        } else {
            self.buttonStyle(.bordered)
        }
    }
}
