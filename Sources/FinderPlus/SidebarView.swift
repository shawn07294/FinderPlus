import SwiftUI

public struct SidebarItem: Identifiable, Hashable {
    public var id: String { url.path }
    public let name: String
    public let systemImage: String
    public let url: URL

    public init(name: String, systemImage: String, url: URL) {
        self.name = name
        self.systemImage = systemImage
        self.url = url
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

    private var locations: [SidebarItem] {
        var items = [
            SidebarItem(name: "Macintosh HD", systemImage: "internaldrive", url: URL(fileURLWithPath: "/"))
        ]

        let volumesURL = URL(fileURLWithPath: "/Volumes")
        if let vols = try? FileManager.default.contentsOfDirectory(at: volumesURL, includingPropertiesForKeys: nil, options: [.skipsHiddenFiles]) {
            for vol in vols {
                if vol.lastPathComponent != "Macintosh HD" {
                    items.append(SidebarItem(name: vol.lastPathComponent, systemImage: "externaldrive", url: vol))
                }
            }
        }
        return items
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
                ForEach(locations) { item in
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

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8 * viewModel.appScale) {
                Image(systemName: item.systemImage)
                    .font(.system(size: 14 * viewModel.appScale))
                    .foregroundColor(.accentColor)
                    .frame(width: 18 * viewModel.appScale)
                Text(item.name)
                    .font(.system(size: 13 * viewModel.appScale))
                Spacer()
            }
            .padding(.vertical, max(2, 4 * viewModel.appScale))
            .padding(.horizontal, max(4, 6 * viewModel.appScale))
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
        }
        .buttonStyle(.plain)
        .dropDestination(for: URL.self) { urls, _ in
            viewModel.handleDrop(urls: urls, targetDirectory: item.url)
        } isTargeted: { targeted in
            isTargeted = targeted
        }
    }
}
