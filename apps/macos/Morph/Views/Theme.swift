import SwiftUI

/// Small shared palette so the UI reads as one system in light and dark.
enum Theme {
    static let accent = Color(red: 0.0, green: 0.478, blue: 1.0)        // system blue
    static let accentDeep = Color(red: 0.0, green: 0.4, blue: 0.9)

    /// Soft gradient glow behind each drop-zone illustration.
    static let convertGlow = [Color(red: 0.18, green: 0.42, blue: 1.0),   // blue
                              Color(red: 0.07, green: 0.71, blue: 0.63)]  // mint
    static let pdfGlow = [Color(red: 0.94, green: 0.27, blue: 0.24),      // red
                          Color(red: 1.0, green: 0.49, blue: 0.34)]       // coral

    static func icon(for category: FileKind?) -> String {
        switch category {
        case .image: return "photo"
        case .document: return "doc.richtext"
        case .data: return "tablecells"
        case .none: return "questionmark.circle"
        }
    }
}
