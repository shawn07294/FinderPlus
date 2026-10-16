import SwiftUI
import AppKit

public struct MainContentView: View {
    @StateObject var viewModel = ExplorerViewModel()
    @FocusState private var isSearchFocused: Bool

    public var body: some View {
        NavigationSplitView {
            SidebarView(viewModel: viewModel)
        } detail: {
            VStack(spacing: 0) {
                // Search Filter Shelf
                if viewModel.isSearchActive || viewModel.showFilterShelf {
                    SearchFilterShelfView(viewModel: viewModel)
                        .transition(.move(edge: .top).combined(with: .opacity))
                }

                // File View Area
                ZStack {
                    if viewModel.displayedItems.isEmpty {
                        emptyStateView
                    } else {
                        Group {
                            switch viewModel.viewMode {
                            case .list:
                                FileListView(viewModel: viewModel)
                            case .icons:
                                FileIconView(viewModel: viewModel)
                            }
                        }
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)

                // Bottom Path Bar & Status
                BottomBarView(viewModel: viewModel)
            }
        }
        .toolbar {
            // Navigation items
            ToolbarItemGroup(placement: .navigation) {
                Button(action: { viewModel.goBack() }) {
                    Image(systemName: "chevron.left")
                }
                .disabled(!viewModel.canGoBack)
                .help("Back")

                Button(action: { viewModel.goForward() }) {
                    Image(systemName: "chevron.right")
                }
                .disabled(!viewModel.canGoForward)
                .help("Forward")
            }

            // Center: Folder Title & View Mode
            ToolbarItemGroup(placement: .principal) {
                HStack(spacing: 12) {
                    Text(viewModel.currentDirectory.lastPathComponent.isEmpty ? "Macintosh HD" : viewModel.currentDirectory.lastPathComponent)
                        .font(.headline)

                    Picker("View Mode", selection: $viewModel.viewMode) {
                        Image(systemName: "square.grid.2x2").tag(ViewMode.icons)
                        Image(systemName: "list.bullet").tag(ViewMode.list)
                    }
                    .pickerStyle(.segmented)
                    .frame(width: 80)
                }
            }

            // Actions & Search
            ToolbarItemGroup(placement: .primaryAction) {
                Button(action: {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        viewModel.showFilterShelf.toggle()
                    }
                }) {
                    Image(systemName: viewModel.showFilterShelf ? "line.3.horizontal.decrease.circle.fill" : "line.3.horizontal.decrease.circle")
                }
                .help("Toggle Search Filter Shelf")

                Button(action: { viewModel.createNewFolder() }) {
                    Image(systemName: "folder.badge.plus")
                }
                .help("New Folder (⌘⇧N)")

                // Search field
                HStack(spacing: 4) {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(.secondary)
                    TextField("Search...", text: $viewModel.searchText)
                        .textFieldStyle(.plain)
                        .focused($isSearchFocused)
                        .frame(width: 160)

                    if !viewModel.searchText.isEmpty {
                        Button(action: { viewModel.clearSearch() }) {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundColor(.secondary)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Color(NSColor.controlBackgroundColor))
                .cornerRadius(8)
            }
        }
        .sheet(item: Binding<PreviewItemWrapper?>(
            get: {
                if let url = viewModel.previewURL {
                    return PreviewItemWrapper(url: url)
                }
                return nil
            },
            set: { wrapper in
                viewModel.previewURL = wrapper?.url
            }
        )) { wrapper in
            QuickLookSheet(url: wrapper.url) {
                viewModel.previewURL = nil
            }
        }
        .onKeyPress(.space) {
            if let first = viewModel.selectedItems.first {
                viewModel.toggleQuickLook(for: first)
                return .handled
            }
            return .ignored
        }
        .onKeyPress(.upArrow, phases: .down) { press in
            if press.modifiers.contains(.command) {
                viewModel.navigateToParent()
                return .handled
            }
            return .ignored
        }
        .onKeyPress(.downArrow, phases: .down) { press in
            if press.modifiers.contains(.command) {
                if let first = viewModel.selectedItems.first {
                    viewModel.openItem(first)
                    return .handled
                }
            }
            return .ignored
        }
        .onKeyPress("f", phases: .down) { press in
            if press.modifiers.contains(.command) {
                isSearchFocused = true
                viewModel.showFilterShelf = true
                return .handled
            }
            return .ignored
        }
        .onKeyPress("+", phases: .down) { press in
            if press.modifiers.contains(.command) {
                viewModel.increaseIconScale()
                return .handled
            }
            return .ignored
        }
        .onKeyPress("=", phases: .down) { press in
            if press.modifiers.contains(.command) {
                viewModel.increaseIconScale()
                return .handled
            }
            return .ignored
        }
        .onKeyPress("-", phases: .down) { press in
            if press.modifiers.contains(.command) {
                viewModel.decreaseIconScale()
                return .handled
            }
            return .ignored
        }
        .onKeyPress("]", phases: .down) { press in
            if press.modifiers.contains(.command) {
                viewModel.increaseAppScale()
                return .handled
            }
            return .ignored
        }
        .onKeyPress("[", phases: .down) { press in
            if press.modifiers.contains(.command) {
                viewModel.decreaseAppScale()
                return .handled
            }
            return .ignored
        }
        .onKeyPress("0", phases: .down) { press in
            if press.modifiers.contains(.command) {
                viewModel.resetScales()
                return .handled
            }
            return .ignored
        }
        .onReceive(NotificationCenter.default.publisher(for: .increaseIconScaleTriggered)) { _ in
            viewModel.increaseIconScale()
        }
        .onReceive(NotificationCenter.default.publisher(for: .decreaseIconScaleTriggered)) { _ in
            viewModel.decreaseIconScale()
        }
        .onReceive(NotificationCenter.default.publisher(for: .increaseAppScaleTriggered)) { _ in
            viewModel.increaseAppScale()
        }
        .onReceive(NotificationCenter.default.publisher(for: .decreaseAppScaleTriggered)) { _ in
            viewModel.decreaseAppScale()
        }
        .onReceive(NotificationCenter.default.publisher(for: .resetScalesTriggered)) { _ in
            viewModel.resetScales()
        }
        .onReceive(NotificationCenter.default.publisher(for: .goBackTriggered)) { _ in
            viewModel.goBack()
        }
        .onReceive(NotificationCenter.default.publisher(for: .goForwardTriggered)) { _ in
            viewModel.goForward()
        }
        .onReceive(NotificationCenter.default.publisher(for: .goUpTriggered)) { _ in
            viewModel.navigateToParent()
        }
        .onReceive(NotificationCenter.default.publisher(for: .goToDirectory)) { notif in
            if let url = notif.object as? URL {
                viewModel.navigateTo(url: url)
            }
        }
        .scaleEffect(viewModel.appScale)
    }

    private var emptyStateView: some View {
        VStack(spacing: 12) {
            Image(systemName: viewModel.isSearchActive ? "magnifyingglass" : "folder")
                .font(.system(size: 48))
                .foregroundColor(.secondary.opacity(0.6))

            Text(viewModel.isSearchActive ? "No matching items found" : "This folder is empty")
                .font(.headline)
                .foregroundColor(.secondary)

            if viewModel.isSearchActive {
                Text("Try adjusting your search query, scope, or filters in the shelf above.")
                    .font(.subheadline)
                    .foregroundColor(.secondary.opacity(0.8))
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 320)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(NSColor.textBackgroundColor))
        .onDrop(of: [.fileURL, .url], delegate: FolderCanvasDropDelegate(viewModel: viewModel))
    }
}

public struct PreviewItemWrapper: Identifiable {
    public var id: String { url.path }
    public let url: URL
}
