import SwiftUI
import AppKit

public struct FileThumbnailView: View {
    let item: FileItem
    let size: CGFloat
    @State private var displayImage: NSImage?

    public init(item: FileItem, size: CGFloat) {
        self.item = item
        self.size = size
        _displayImage = State(initialValue: ThumbnailService.shared.cachedThumbnail(for: item, size: size))
    }

    public var body: some View {
        Group {
            if let img = displayImage {
                Image(nsImage: img)
                    .resizable()
                    .scaledToFit()
            } else {
                Image(nsImage: item.icon)
                    .resizable()
                    .scaledToFit()
            }
        }
        .frame(width: size, height: size)
        .task(id: "\(item.id)_\(Int(size))") {
            loadThumbnail()
        }
        .onChange(of: item.id) { _, _ in
            loadThumbnail()
        }
        .onReceive(NotificationCenter.default.publisher(for: .previewThumbnailsDidUpdate)) { _ in
            loadThumbnail()
        }
    }

    private func loadThumbnail() {
        if let cached = ThumbnailService.shared.cachedThumbnail(for: item, size: size) {
            self.displayImage = cached
            return
        }

        if ThumbnailService.shared.isPreviewEligible(item: item) {
            ThumbnailService.shared.loadThumbnail(for: item, targetSize: size) { thumb in
                Task { @MainActor in
                    self.displayImage = thumb
                }
            }
        } else {
            self.displayImage = nil
        }
    }
}
