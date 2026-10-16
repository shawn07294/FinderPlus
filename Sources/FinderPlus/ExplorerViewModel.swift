import Foundation
import AppKit
import SwiftUI
import Combine

public enum ViewMode: String, CaseIterable, Identifiable {
    case icons = "Icons"
    case list = "List"

    public var id: String { rawValue }

    public var systemImage: String {
        switch self {
        case .icons: return "square.grid.2x2"
        case .list: return "list.bullet"
        }
    }
}

public enum SortField: String, CaseIterable, Identifiable {
    case name = "Name"
    case dateModified = "Date Modified"
    case size = "Size"
    case kind = "Kind"

    public var id: String { rawValue }
}

public enum SortOrder {
    case ascending
    case descending
}

@MainActor
public final class ExplorerViewModel: ObservableObject {
    // Navigation State
    @Published public var currentDirectory: URL {
        didSet {
            loadCurrentDirectory()
            if isSearchActive && searchParameters.scope == .currentFolderOnly {
                triggerSearch()
            }
        }
    }
    @Published public private(set) var history: [URL] = []
    @Published public private(set) var historyIndex: Int = -1

    // View & Layout
    @Published public var viewMode: ViewMode = .list
    @Published public var sortField: SortField = .name {
        didSet { updateDisplayedItems() }
    }
    @Published public var sortAscending: Bool = true {
        didSet { updateDisplayedItems() }
    }

    // Directory Content
    @Published public private(set) var folderItems: [FileItem] = [] {
        didSet { updateDisplayedItems() }
    }
    @Published public var selectedItemIDs: Set<String> = []

    // Search
    @Published public var searchText: String = "" {
        didSet {
            if searchText != oldValue {
                searchDebounceSubject.send(searchText)
            }
            if searchText.isEmpty {
                updateDisplayedItems()
            }
        }
    }
    @Published public var searchParameters: SearchParameters = SearchParameters() {
        didSet {
            if isSearchActive {
                triggerSearch()
            }
        }
    }
    @Published public private(set) var isSearching: Bool = false
    @Published public private(set) var searchResults: [FileItem] = [] {
        didSet { updateDisplayedItems() }
    }
    @Published public private(set) var scannedCount: Int = 0
    @Published public var showFilterShelf: Bool = false

    // Cached sorted displayed items - never re-sorts on selection or drag changes!
    @Published public private(set) var displayedItems: [FileItem] = []

    // Scaling States
    @Published public var iconScale: Double = 1.0
    @Published public var appScale: Double = 1.0

    public func increaseIconScale() {
        withAnimation(.easeInOut(duration: 0.15)) {
            iconScale = min(iconScale + 0.15, 2.5)
        }
    }

    public func decreaseIconScale() {
        withAnimation(.easeInOut(duration: 0.15)) {
            iconScale = max(iconScale - 0.15, 0.5)
        }
    }

    public func increaseAppScale() {
        withAnimation(.easeInOut(duration: 0.15)) {
            appScale = min(round((appScale + 0.1) * 10) / 10, 1.8)
        }
    }

    public func decreaseAppScale() {
        withAnimation(.easeInOut(duration: 0.15)) {
            appScale = max(round((appScale - 0.1) * 10) / 10, 0.7)
        }
    }

    public func resetScales() {
        withAnimation(.easeInOut(duration: 0.15)) {
            iconScale = 1.0
            appScale = 1.0
        }
    }

    public var controlSize: ControlSize {
        if appScale >= 1.2 {
            return .large
        } else if appScale <= 0.85 {
            return .small
        } else {
            return .regular
        }
    }

    // Quick Look
    @Published public var previewURL: URL? = nil

    // Drag State
    @Published public var draggingItemID: String? = nil

    // Status bar stats
    @Published public private(set) var volumeFreeSpaceString: String = ""

    private let searchEngine = SearchEngine()
    private var searchTask: Task<Void, Never>?
    private var searchDebounceSubject = PassthroughSubject<String, Never>()
    private var cancellables = Set<AnyCancellable>()

    public init(initialDirectory: URL = FileManager.default.homeDirectoryForCurrentUser) {
        self.currentDirectory = initialDirectory
        self.history = [initialDirectory]
        self.historyIndex = 0

        setupDebouncedSearch()
        loadCurrentDirectory()
        updateVolumeSpace()

        NSEvent.addLocalMonitorForEvents(matching: [.leftMouseUp]) { [weak self] event in
            Task { @MainActor in
                if self?.draggingItemID != nil {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                        self?.draggingItemID = nil
                    }
                }
            }
            return event
        }
        NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseUp]) { [weak self] _ in
            Task { @MainActor in
                if self?.draggingItemID != nil {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                        self?.draggingItemID = nil
                    }
                }
            }
        }
    }

    private func setupDebouncedSearch() {
        searchDebounceSubject
            .debounce(for: .milliseconds(250), scheduler: RunLoop.main)
            .sink { [weak self] _ in
                self?.triggerSearch()
            }
            .store(in: &cancellables)
    }

    public var isSearchActive: Bool {
        !searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    public func updateDisplayedItems() {
        let items = isSearchActive ? searchResults : folderItems
        self.displayedItems = sortItems(items)
    }

    public var selectedItems: [FileItem] {
        displayedItems.filter { selectedItemIDs.contains($0.id) }
    }

    private func sortItems(_ items: [FileItem]) -> [FileItem] {
        items.sorted { lhs, rhs in
            // Folders usually on top in Finder-like style
            if lhs.isDirectory != rhs.isDirectory {
                return lhs.isDirectory && !rhs.isDirectory
            }

            let comparison: ComparisonResult
            switch sortField {
            case .name:
                comparison = lhs.name.localizedStandardCompare(rhs.name)
            case .dateModified:
                let lDate = lhs.dateModified ?? Date.distantPast
                let rDate = rhs.dateModified ?? Date.distantPast
                comparison = lDate.compare(rDate)
            case .size:
                comparison = lhs.size < rhs.size ? .orderedAscending : (lhs.size > rhs.size ? .orderedDescending : .orderedSame)
            case .kind:
                comparison = lhs.kindDescription.localizedStandardCompare(rhs.kindDescription)
            }

            return sortAscending ? comparison == .orderedAscending : comparison == .orderedDescending
        }
    }

    // MARK: - Navigation

    public var canGoBack: Bool {
        historyIndex > 0
    }

    public var canGoForward: Bool {
        historyIndex < history.count - 1
    }

    public func goBack() {
        guard canGoBack else { return }
        historyIndex -= 1
        currentDirectory = history[historyIndex]
    }

    public func goForward() {
        guard canGoForward else { return }
        historyIndex += 1
        currentDirectory = history[historyIndex]
    }

    public func navigateTo(url: URL) {
        let standardized = url.standardizedFileURL
        guard standardized != currentDirectory else { return }

        if historyIndex < history.count - 1 {
            history.removeSubrange((historyIndex + 1)...)
        }
        history.append(standardized)
        historyIndex = history.count - 1
        currentDirectory = standardized
    }

    public func navigateToParent() {
        let parent = currentDirectory.deletingLastPathComponent()
        if parent != currentDirectory {
            navigateTo(url: parent)
        }
    }

    public var breadcrumbs: [URL] {
        var crumbs: [URL] = []
        var url = currentDirectory.standardizedFileURL
        while url.path != "/" && !url.path.isEmpty {
            crumbs.insert(url, at: 0)
            url = url.deletingLastPathComponent()
        }
        crumbs.insert(URL(fileURLWithPath: "/"), at: 0)
        return crumbs
    }

    // MARK: - Directory Loading

    public func loadCurrentDirectory() {
        selectedItemIDs.removeAll()
        let keys: [URLResourceKey] = [
            .isDirectoryKey,
            .isPackageKey,
            .isHiddenKey,
            .fileSizeKey,
            .contentModificationDateKey,
            .contentTypeKey,
            .localizedTypeDescriptionKey
        ]

        var options: FileManager.DirectoryEnumerationOptions = []
        if !searchParameters.includeHiddenFiles {
            options.insert(.skipsHiddenFiles)
        }

        let urls = (try? FileManager.default.contentsOfDirectory(
            at: currentDirectory,
            includingPropertiesForKeys: keys,
            options: options
        )) ?? []

        self.folderItems = urls.map { FileItem(url: $0) }
        updateVolumeSpace()
    }

    // MARK: - Search Execution

    public func triggerSearch() {
        searchTask?.cancel()
        searchTask = nil

        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else {
            isSearching = false
            searchResults = []
            scannedCount = 0
            return
        }

        isSearching = true
        searchResults = []
        scannedCount = 0

        let baseDir = currentDirectory
        let params = searchParameters

        searchTask = Task { [weak self] in
            guard let self = self else { return }

            let stream = await self.searchEngine.search(
                query: query,
                baseDirectory: baseDir,
                parameters: params,
                onProgress: { [weak self] progress in
                    Task { @MainActor in
                        self?.scannedCount = progress.scannedCount
                    }
                }
            )

            var buffer: [FileItem] = []
            var lastUpdate = Date()

            for await item in stream {
                if Task.isCancelled { break }
                buffer.append(item)

                if Date().timeIntervalSince(lastUpdate) > 0.1 || buffer.count >= 20 {
                    self.searchResults.append(contentsOf: buffer)
                    buffer.removeAll(keepingCapacity: true)
                    lastUpdate = Date()
                }
            }

            if !buffer.isEmpty && !Task.isCancelled {
                self.searchResults.append(contentsOf: buffer)
            }

            self.isSearching = false
        }
    }

    public func cancelSearch() {
        searchTask?.cancel()
        searchTask = nil
        isSearching = false
    }

    public func clearSearch() {
        cancelSearch()
        searchText = ""
        searchResults = []
    }

    // MARK: - File Actions

    public func openItem(_ item: FileItem) {
        if item.isDirectory {
            navigateTo(url: item.url)
        } else {
            NSWorkspace.shared.open(item.url)
        }
    }

    public func revealInFinder(_ item: FileItem) {
        NSWorkspace.shared.activateFileViewerSelecting([item.url])
    }

    public func copyPath(_ item: FileItem) {
        let pb = NSPasteboard.general
        pb.clearContents()
        pb.setString(item.url.path, forType: .string)
    }

    public func moveToTrash(_ items: [FileItem]) {
        for item in items {
            do {
                try FileManager.default.trashItem(at: item.url, resultingItemURL: nil)
            } catch {
                print("Error trashing \(item.url.path): \(error)")
            }
        }
        loadCurrentDirectory()
        if isSearchActive {
            triggerSearch()
        }
    }

    public func createNewFolder(name: String = "untitled folder") {
        var finalName = name
        var count = 2
        var targetURL = currentDirectory.appendingPathComponent(finalName)

        while FileManager.default.fileExists(atPath: targetURL.path) {
            finalName = "\(name) \(count)"
            targetURL = currentDirectory.appendingPathComponent(finalName)
            count += 1
        }

        do {
            try FileManager.default.createDirectory(at: targetURL, withIntermediateDirectories: true)
            loadCurrentDirectory()
            selectedItemIDs = [targetURL.path]
        } catch {
            print("Error creating folder: \(error)")
        }
    }

    public func renameItem(_ item: FileItem, to newName: String) {
        let trimmed = newName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, trimmed != item.name else { return }

        let targetURL = item.url.deletingLastPathComponent().appendingPathComponent(trimmed)
        do {
            try FileManager.default.moveItem(at: item.url, to: targetURL)
            loadCurrentDirectory()
            if isSearchActive {
                triggerSearch()
            }
        } catch {
            print("Error renaming file: \(error)")
        }
    }

    public func duplicateItem(_ item: FileItem) {
        let folder = item.url.deletingLastPathComponent()
        let ext = item.url.pathExtension
        let baseName = item.url.deletingPathExtension().lastPathComponent

        var copyName = ext.isEmpty ? "\(baseName) copy" : "\(baseName) copy.\(ext)"
        var target = folder.appendingPathComponent(copyName)
        var count = 2

        while FileManager.default.fileExists(atPath: target.path) {
            copyName = ext.isEmpty ? "\(baseName) copy \(count)" : "\(baseName) copy \(count).\(ext)"
            target = folder.appendingPathComponent(copyName)
            count += 1
        }

        do {
            try FileManager.default.copyItem(at: item.url, to: target)
            loadCurrentDirectory()
        } catch {
            print("Error duplicating: \(error)")
        }
    }

    public func toggleQuickLook(for item: FileItem?) {
        guard let item = item ?? selectedItems.first else {
            previewURL = nil
            return
        }
        if previewURL == item.url {
            previewURL = nil
        } else {
            previewURL = item.url
        }
    }

    // MARK: - Drag & Drop Handling

    @discardableResult
    public func handleDrop(urls: [URL], targetDirectory: URL) -> Bool {
        var didMoveAny = false
        let targetDirStandardized = targetDirectory.standardizedFileURL

        for sourceURL in urls {
            let sourceStandardized = sourceURL.standardizedFileURL
            // Don't move a file to its current parent folder
            if sourceStandardized.deletingLastPathComponent() == targetDirStandardized {
                continue
            }
            // Prevent dropping a folder into itself or any of its subfolders
            if targetDirStandardized.path == sourceStandardized.path || targetDirStandardized.path.hasPrefix(sourceStandardized.path + "/") {
                continue
            }

            var destURL = targetDirStandardized.appendingPathComponent(sourceStandardized.lastPathComponent)

            // Resolve name collision if file/folder already exists at destination
            if FileManager.default.fileExists(atPath: destURL.path) {
                let ext = destURL.pathExtension
                let base = destURL.deletingPathExtension().lastPathComponent
                var counter = 2
                while FileManager.default.fileExists(atPath: destURL.path) {
                    let newName = ext.isEmpty ? "\(base) \(counter)" : "\(base) \(counter).\(ext)"
                    destURL = targetDirStandardized.appendingPathComponent(newName)
                    counter += 1
                }
            }

            do {
                try FileManager.default.moveItem(at: sourceStandardized, to: destURL)
                didMoveAny = true
            } catch {
                // If cross-volume move fails, try copy then remove
                do {
                    try FileManager.default.copyItem(at: sourceStandardized, to: destURL)
                    try? FileManager.default.removeItem(at: sourceStandardized)
                    didMoveAny = true
                } catch {
                    print("Error moving \(sourceStandardized.path) to \(destURL.path): \(error)")
                }
            }
        }

        draggingItemID = nil
        if didMoveAny {
            loadCurrentDirectory()
            if isSearchActive {
                triggerSearch()
            }
        }

        return didMoveAny
    }

    private func updateVolumeSpace() {
        if let values = try? currentDirectory.resourceValues(forKeys: [.volumeAvailableCapacityForImportantUsageKey]) {
            if let free = values.volumeAvailableCapacityForImportantUsage {
                let formatted = ByteCountFormatter.string(fromByteCount: free, countStyle: .file)
                self.volumeFreeSpaceString = "\(formatted) available"
                return
            }
        }
        self.volumeFreeSpaceString = ""
    }
}
