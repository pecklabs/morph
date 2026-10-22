import SwiftUI
import AppKit
import QuickLookThumbnailing

/// Caches QuickLook thumbnails so rows don't regenerate them on every redraw.
@MainActor
final class ThumbnailCache {
    static let shared = ThumbnailCache()
    /// Keyed by url + requested size so a small list thumbnail never gets
    /// reused (upscaled and blurry) for a large grid tile.
    private var cache: [String: NSImage] = [:]

    private func key(_ url: URL, _ side: CGFloat) -> String { "\(url.path)|\(Int(side))" }

    func cached(_ url: URL, side: CGFloat) -> NSImage? { cache[key(url, side)] }

    func thumbnail(for url: URL, size: CGFloat) async -> NSImage? {
        let k = key(url, size)
        if let img = cache[k] { return img }
        // Oversample (2× the screen scale) so tiles stay crisp when the image
        // is cropped to fill, and so a resize still has pixels to spare.
        let scale = (NSScreen.main?.backingScaleFactor ?? 2) * 2
        let request = QLThumbnailGenerator.Request(
            fileAt: url,
            size: CGSize(width: size, height: size),
            scale: scale,
            representationTypes: .all
        )
        guard let rep = try? await QLThumbnailGenerator.shared.generateBestRepresentation(for: request) else {
            return nil
        }
        let img = rep.nsImage
        cache[k] = img
        return img
    }
}

/// A real thumbnail preview for a file, falling back to the system file-type icon.
struct ThumbnailView: View {
    let url: URL
    var side: CGFloat = 40

    @State private var image: NSImage?
    @State private var isPreview = false

    var body: some View {
        ZStack {
            if let image {
                Image(nsImage: image)
                    .resizable()
                    .aspectRatio(contentMode: isPreview ? .fill : .fit)
                    .padding(isPreview ? 0 : 5)
            } else {
                Image(nsImage: NSWorkspace.shared.icon(forFile: url.path))
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .padding(4)
            }
        }
        .frame(width: side, height: side)
        .background(Color(nsColor: .windowBackgroundColor))
        .clipShape(RoundedRectangle(cornerRadius: 7))
        .overlay(
            RoundedRectangle(cornerRadius: 7)
                .strokeBorder(Color.primary.opacity(0.08))
        )
        .task(id: url) {
            if let hit = ThumbnailCache.shared.cached(url, side: side) {
                image = hit
                isPreview = true
                return
            }
            if let generated = await ThumbnailCache.shared.thumbnail(for: url, size: side) {
                image = generated
                isPreview = true
            }
        }
    }
}
