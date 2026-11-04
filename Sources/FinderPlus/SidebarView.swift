import SwiftUI

public struct SidebarItem: Identifiable, Hashable, Equatable {
    public var id: String { url.path }
    public let name: String
    public let systemImage: String
    public let url: URL
    public let isEjectable: Bool

    public init(name: String, systemImage: String, url: URL, isEjectable: Bool = false) {
        self.name = name
        self.systemImage = systemImage
        self.url = url
        self.isEjectable = isEjectable
    }
}

public struct SidebarView: View {
    @ObservedObject var viewModel: ExplorerViewModel

    private var favorites: [SidebarItem] {
        let fm = FileManager.default
        let home = fm.homeDirectoryForCurrentUser

        return [
            SidebarItem(name: "Home", systemImage: "house", url: home),
            SidebarItem(name: "Desktop", systemImage: "desktopcomputer", url: home.appendingPathComponent("Desktop")),
            SidebarItem(name: "Documents", systemImage: "doc.text", url: home.appendingPathComponent("Documents")),
            SidebarItem(name: "Downloads", systemImage: "arrow.down.circle", url: home.appendingPathComponent("Downloads")),
            SidebarItem(name: "Applications", systemImage: "app.badge", url: URL(fileURLWithPath: "/Applications"))
        ]
    }

    public var body: some View {
        List {
            Section("Favorites") {
                ForEach(favorites) { item in
                    SidebarRow(
                        item: item,
                        isSelected: viewModel.currentDirectory.standardizedFileURL == item.url.standardizedFileURL,
                        viewModel: viewModel
                    ) {
                        viewModel.navigateTo(url: item.url)
                    }
                }
            }

            Section("Locations") {
                ForEach(viewModel.locations) { item in
                    SidebarRow(
                        item: item,
                        isSelected: viewModel.currentDirectory.standardizedFileURL == item.url.standardizedFileURL,
                        viewModel: viewModel
                    ) {
                        viewModel.navigateTo(url: item.url)
                    }
                }
            }
        }
        .listStyle(.sidebar)
        .frame(
            minWidth: max(160, 180 * viewModel.appScale),
            idealWidth: max(180, 200 * viewModel.appScale),
            maxWidth: max(240, 280 * viewModel.appScale)
        )
    }
}

private struct SidebarRow: View {
    let item: SidebarItem
    let isSelected: Bool
    @ObservedObject var viewModel: ExplorerViewModel
    let action: () -> Void
    @State private var isTargeted: Bool = false
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        HStack(spacing: 0) {
            Button(action: action) {
                HStack(spacing: 8 * viewModel.appScale) {
                    Image(systemName: item.systemImage)
                        .font(.system(size: 14 * viewModel.appScale))
                        .foregroundColor(.accentColor)
                        .frame(width: 18 * viewModel.appScale)

                    Text(item.name)
                        .font(.system(size: 13 * viewModel.appScale))
                        .lineLimit(1)

                    Spacer(minLength: 0)
                }
                .contentShape(Rectangle())
                .padding(.vertical, max(2, 4 * viewModel.appScale))
                .padding(.horizontal, max(4, 6 * viewModel.appScale))
            }
            .buttonStyle(.plain)
            .contentShape(Rectangle())

            if item.isEjectable {
                Button(action: {
                    viewModel.ejectVolume(at: item.url)
                }) {
                    Image(systemName: "eject.circle.fill")
                        .font(.system(size: 13 * viewModel.appScale))
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
                .help("Eject \"\(item.name)\"")
                .padding(.trailing, 6)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .contentShape(Rectangle())
        .background(
            isTargeted
                ? Color.accentColor.opacity(0.35)
                : (isSelected ? Color.accentColor.opacity(0.18) : Color.clear)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 6)
                .stroke(isTargeted ? Color.accentColor : Color.clear, lineWidth: 1.5)
        )
        .cornerRadius(6)
        .contextMenu {
            Button("Open") {
                action()
            }
            Button("Open in New Window") {
                openWindow(value: item.url)
            }
            Divider()
            Button("Reveal in Finder") {
                NSWorkspace.shared.activateFileViewerSelecting([item.url])
            }
            Button("Copy Path") {
                let pb = NSPasteboard.general
                pb.clearContents()
                pb.setString(item.url.path, forType: .string)
            }
            Divider()
            Menu("Load All Previews") {
                Button("entire drive (including subfolders)") {
                    viewModel.loadAllPreviews(for: item.url, recursive: true)
                }
                Button("this folder only") {
                    viewModel.loadAllPreviews(for: item.url, recursive: false)
                }
            }
            if item.isEjectable {
                Divider()
                Button("Eject \"\(item.name)\"") {
                    viewModel.ejectVolume(at: item.url)
                }
            }
        }
        .dropDestination(for: URL.self) { urls, _ in
            viewModel.handleDrop(urls: urls, targetDirectory: item.url)
        } isTargeted: { targeted in
            isTargeted = targeted
        }
    }
}
