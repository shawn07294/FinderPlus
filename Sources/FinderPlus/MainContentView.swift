import SwiftUI
import AppKit

public struct MainContentView: View {
    @StateObject var viewModel: ExplorerViewModel
    @FocusState private var isSearchFocused: Bool

    public init(initialDirectory: URL = FileManager.default.homeDirectoryForCurrentUser) {
        _viewModel = StateObject(wrappedValue: ExplorerViewModel(initialDirectory: initialDirectory))
    }

    private var currentFolderName: String {
        let name = viewModel.currentDirectory.lastPathComponent
        return (name.isEmpty || viewModel.currentDirectory.path == "/") ? "Macintosh HD" : name
    }

    public var body: some View {
        ZStack {
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

            // Full-window maximized Quick Look preview overlay
            if let url = viewModel.previewURL {
                QuickLookOverlay(url: url) {
                    withAnimation(.easeOut(duration: 0.15)) {
                        viewModel.previewURL = nil
                    }
                }
                .transition(.opacity)
                .zIndex(100)
            }
        }
        .toolbar {
            // Left (Leading): Navigation & Folder Title
            ToolbarItemGroup(placement: .navigation) {
                Button(action: { viewModel.goBack() }) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 13 * viewModel.appScale))
                }
                .disabled(!viewModel.canGoBack)
                .help("Back")

                Button(action: { viewModel.goForward() }) {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 13 * viewModel.appScale))
                }
                .disabled(!viewModel.canGoForward)
                .help("Forward")
            }

            // Right Corner (Trailing): View Mode, Sort by, New Folder & Search Bar
            ToolbarItemGroup(placement: .primaryAction) {
                Picker("View Mode", selection: $viewModel.viewMode) {
                    Image(systemName: "square.grid.2x2").tag(ViewMode.icons)
                    Image(systemName: "list.bullet").tag(ViewMode.list)
                }
                .pickerStyle(.segmented)
                .frame(width: max(72, 78 * viewModel.appScale))

                // "Sort by" button with options (Name, Kind, Size, Date Created, Date Modified)
                Menu {
                    Section("Sort by") {
                        ForEach(SortField.allCases) { field in
                            Button(action: {
                                if viewModel.sortField == field {
                                    viewModel.sortAscending.toggle()
                                } else {
                                    viewModel.sortField = field
                                    viewModel.sortAscending = true
                                }
                            }) {
                                HStack {
                                    Text(field.rawValue)
                                    if viewModel.sortField == field {
                                        Image(systemName: "checkmark")
                                    }
                                }
                            }
                        }
                    }

                    Divider()

                    Section("Order") {
                        Button(action: { viewModel.sortAscending = true }) {
                            HStack {
                                Text("Ascending")
                                if viewModel.sortAscending { Image(systemName: "checkmark") }
                            }
                        }
                        Button(action: { viewModel.sortAscending = false }) {
                            HStack {
                                Text("Descending")
                                if !viewModel.sortAscending { Image(systemName: "checkmark") }
                            }
                        }
                    }
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "arrow.up.arrow.down")
                            .font(.system(size: 12 * viewModel.appScale))
                        Text("Sort by")
                            .font(.system(size: 12 * viewModel.appScale))
                    }
                }
                .help("Sort by (Name, Kind, Size, Date Created, Date Modified)")

                Button(action: { viewModel.createNewFolder() }) {
                    Image(systemName: "folder.badge.plus")
                        .font(.system(size: 13 * viewModel.appScale))
                }
                .help("New Folder (⌘⇧N)")

                // Search field positioned in the right corner
                HStack(spacing: 4) {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(.secondary)
                    TextField("Search...", text: $viewModel.searchText)
                        .textFieldStyle(.plain)
                        .focused($isSearchFocused)
                        .frame(width: max(160, 180 * viewModel.appScale))

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
        .sheet(isPresented: $viewModel.showShortcutsSheet) {
            KeyboardShortcutsSheet(isPresented: $viewModel.showShortcutsSheet)
        }
        .navigationTitle(currentFolderName)
        .background(
            WindowAccessor { window in
                if window.title != currentFolderName {
                    window.title = currentFolderName
                }
                window.representedURL = viewModel.currentDirectory
            }
        )
        .modifier(MainContentKeyboardShortcutsModifier(viewModel: viewModel, isSearchFocused: $isSearchFocused))
        .modifier(MainContentNotificationObserversModifier(viewModel: viewModel))
        .controlSize(viewModel.controlSize)
        .onChange(of: isSearchFocused) { _, focused in
            if focused {
                withAnimation(.easeInOut(duration: 0.2)) {
                    viewModel.showFilterShelf = true
                }
            }
        }
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

private struct MainContentKeyboardShortcutsModifier: ViewModifier {
    @ObservedObject var viewModel: ExplorerViewModel
    @FocusState.Binding var isSearchFocused: Bool
    @Environment(\.openWindow) private var openWindow

    func body(content: Content) -> some View {
        content
            .onKeyPress(.space) {
                if viewModel.previewURL != nil {
                    withAnimation(.easeOut(duration: 0.15)) {
                        viewModel.previewURL = nil
                    }
                    return .handled
                }
                if let first = viewModel.selectedItems.first {
                    withAnimation(.easeIn(duration: 0.15)) {
                        viewModel.toggleQuickLook(for: first)
                    }
                    return .handled
                }
                return .ignored
            }
            .onKeyPress(.escape) {
                if viewModel.previewURL != nil {
                    withAnimation(.easeOut(duration: 0.15)) {
                        viewModel.previewURL = nil
                    }
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
            .onKeyPress("/", phases: .down) { press in
                if press.modifiers.contains(.command) {
                    viewModel.showShortcutsSheet.toggle()
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
            .onKeyPress(.delete, phases: .down) { press in
                if press.modifiers.contains(.command) {
                    let items = viewModel.selectedItems
                    if !items.isEmpty {
                        viewModel.moveToTrash(items)
                        return .handled
                    }
                }
                return .ignored
            }
            .onKeyPress("n", phases: .down) { press in
                if press.modifiers == [.command] {
                    openWindow(id: "main-window")
                    return .handled
                }
                return .ignored
            }
    }
}

private struct MainContentNotificationObserversModifier: ViewModifier {
    @ObservedObject var viewModel: ExplorerViewModel

    func body(content: Content) -> some View {
        content
            .onReceive(NotificationCenter.default.publisher(for: .moveToTrashTriggered)) { _ in
                let items = viewModel.selectedItems
                if !items.isEmpty {
                    viewModel.moveToTrash(items)
                }
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
            .onReceive(NotificationCenter.default.publisher(for: .toggleShortcutsSheetTriggered)) { _ in
                viewModel.showShortcutsSheet.toggle()
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
    }
}

public struct PreviewItemWrapper: Identifiable {
    public var id: String { url.path }
    public let url: URL
}
