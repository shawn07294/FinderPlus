import SwiftUI
import QuickLookUI
import AppKit

public struct QuickLookRepresentable: NSViewRepresentable {
    public let url: URL

    public init(url: URL) {
        self.url = url
    }

    public func makeNSView(context: Context) -> QLPreviewView {
        let view = QLPreviewView(frame: .zero, style: .normal) ?? QLPreviewView()
        view.previewItem = url as QLPreviewItem
        view.autostarts = true
        return view
    }

    public func updateNSView(_ nsView: QLPreviewView, context: Context) {
        if (nsView.previewItem as? URL) != url {
            nsView.previewItem = url as QLPreviewItem
        }
    }
}

public struct QuickLookOverlay: View {
    public let url: URL
    public let onClose: () -> Void

    public var body: some View {
        ZStack {
            // Dark dimming backdrop to focus on the preview
            Color.black.opacity(0.45)
                .ignoresSafeArea()
                .onTapGesture {
                    onClose()
                }

            // Window-filling preview card taking up virtually 100% of the window
            VStack(spacing: 0) {
                // Header Bar
                HStack(spacing: 10) {
                    Image(nsImage: NSWorkspace.shared.icon(forFile: url.path))
                        .resizable()
                        .scaledToFit()
                        .frame(width: 18, height: 18)

                    Text(url.lastPathComponent)
                        .font(.headline)
                        .lineLimit(1)

                    Spacer()

                    Button(action: onClose) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 20))
                            .foregroundColor(.secondary)
                    }
                    .buttonStyle(.plain)
                    .help("Close Preview (Space or Esc)")
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .background(Material.regular)

                Divider()

                // Full-size Quick Look view taking maximum space
                QuickLookRepresentable(url: url)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            .background(Color(NSColor.windowBackgroundColor))
            .cornerRadius(12)
            .shadow(color: .black.opacity(0.4), radius: 24, x: 0, y: 10)
            .padding(14)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

public struct QuickLookSheet: View {
    public let url: URL
    public let onClose: () -> Void

    public var body: some View {
        QuickLookOverlay(url: url, onClose: onClose)
            .frame(minWidth: 700, maxWidth: .infinity, minHeight: 500, maxHeight: .infinity)
    }
}
