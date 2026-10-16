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
                    .task(id: item.id) {
                        if ThumbnailService.shared.isPreviewEligible(item: item) {
                            ThumbnailService.shared.loadThumbnail(for: item, targetSize: size) { thumb in
                                Task { @MainActor in
                                    self.displayImage = thumb
                                }
                            }
                        }
                    }
            }
        }
        .frame(width: size, height: size)
    }
}
