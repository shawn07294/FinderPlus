import SwiftUI
import AppKit

public struct BottomBarView: View {
    @ObservedObject var viewModel: ExplorerViewModel

    public var body: some View {
        VStack(spacing: 0) {
            Divider()

            HStack(spacing: 0) {
                // Clickable & Droppable Breadcrumb Path Bar
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 4) {
                        ForEach(Array(viewModel.breadcrumbs.enumerated()), id: \.offset) { index, url in
                            BreadcrumbElement(url: url, index: index, totalCount: viewModel.breadcrumbs.count, viewModel: viewModel)

                            if index < viewModel.breadcrumbs.count - 1 {
                                Image(systemName: "chevron.right")
                                    .font(.system(size: 8, weight: .bold))
                                    .foregroundColor(.secondary.opacity(0.6))
                            }
                        }
                    }
                    .padding(.horizontal, 8)
                }

                Spacer(minLength: 12)

                // Status Bar Stats
                HStack(spacing: 8) {
                    if viewModel.isSearchActive {
                        Text("\(viewModel.searchResults.count) \(viewModel.searchResults.count == 1 ? "item" : "items")")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    } else {
                        let total = viewModel.folderItems.count
                        let selected = viewModel.selectedItemIDs.count
                        let text = selected > 0 ? "\(selected) of \(total) selected" : "\(total) \(total == 1 ? "item" : "items")"
                        Text(text)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }

                    if !viewModel.volumeFreeSpaceString.isEmpty {
                        Text("•")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Text(viewModel.volumeFreeSpaceString)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }

                    if viewModel.iconScale != 1.0 || viewModel.appScale != 1.0 {
                        Text("•")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Text("Icon: \(Int(round(viewModel.iconScale * 100)))% • App: \(Int(round(viewModel.appScale * 100)))%")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                }
                .padding(.trailing, 16)
            }
            .frame(height: 28)
            .background(Color(NSColor.windowBackgroundColor))
        }
    }
}

private struct BreadcrumbElement: View {
    let url: URL
    let index: Int
    let totalCount: Int
    @ObservedObject var viewModel: ExplorerViewModel
    @State private var isTargeted: Bool = false

    private var title: String {
        url.path == "/" ? "Macintosh HD" : url.lastPathComponent
    }

    private var isCurrentDirectory: Bool {
        index == totalCount - 1
    }

    var body: some View {
        Button(action: {
            viewModel.navigateTo(url: url)
        }) {
            HStack(spacing: 4) {
                Image(nsImage: NSWorkspace.shared.icon(forFile: url.path))
                    .resizable()
                    .scaledToFit()
                    .frame(width: 14, height: 14)

                Text(title)
                    .font(.caption)
                    .foregroundColor(isCurrentDirectory ? .primary : .secondary)
            }
            .padding(.horizontal, 4)
            .padding(.vertical, 2)
            .background(
                isTargeted
                    ? Color.accentColor.opacity(0.35)
                    : Color.secondary.opacity(0.08)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 4)
                    .stroke(isTargeted ? Color.accentColor : Color.clear, lineWidth: 1.5)
            )
            .cornerRadius(4)
        }
        .buttonStyle(.plain)
        .dropDestination(for: URL.self) { urls, _ in
            viewModel.handleDrop(urls: urls, targetDirectory: url)
        } isTargeted: { targeted in
            isTargeted = targeted
        }
    }
}
