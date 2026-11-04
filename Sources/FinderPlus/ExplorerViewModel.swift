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
    case kind = "Kind"
    case size = "Size"
    case dateCreated = "Date Created"
    case dateModified = "Date Modified"

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
    /// The anchor item for shift-click range selection
    public var lastClickedItemID: String?

    /// Handles item selection with modifier key support.
    /// - plain click: select only this item
    /// - cmd+click: toggle this item in/out of selection
    /// - shift+click: range-select from anchor to this item
    public func selectItem(_ item: FileItem, shiftHeld: Bool, cmdHeld: Bool) {
        if shiftHeld, let anchorID = lastClickedItemID,
           let anchorIndex = displayedItems.firstIndex(where: { $0.id == anchorID }),
           let targetIndex = displayedItems.firstIndex(where: { $0.id == item.id }) {
            let range = min(anchorIndex, targetIndex)...max(anchorIndex, targetIndex)
            let rangeIDs = Set(displayedItems[range].map { $0.id })
            if cmdHeld {
                selectedItemIDs.formUnion(rangeIDs)
            } else {
                selectedItemIDs = rangeIDs
            }
            // Don't update anchor on shift-click so user can extend further
        } else if cmdHeld {
            if selectedItemIDs.contains(item.id) {
                selectedItemIDs.remove(item.id)
            } else {
                selectedItemIDs.insert(item.id)
            }
            lastClickedItemID = item.id
        } else {
            selectedItemIDs = [item.id]
            lastClickedItemID = item.id
        }
    }

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
    @Published public private(set) var searchPercentage: Double = 0.0
    @Published public var showFilterShelf: Bool = false
    @Published public var showShortcutsSheet: Bool = false
    @Published public var statusMessage: String? = nil

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

    // External Drives & Locations
    @Published public var locations: [SidebarItem] = []

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
        setupDriveMonitoring()

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

    private func setupDriveMonitoring() {
        updateConnectedDrives()

        // Check for new external drives connected every 5 seconds
        Timer.publish(every: 5.0, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                self?.updateConnectedDrives()
            }
            .store(in: &cancellables)

        // Also react immediately to system mount/unmount notifications
        NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didMountNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                self?.updateConnectedDrives()
            }
        }

        NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didUnmountNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                self?.updateConnectedDrives()
            }
        }
    }

    public func updateConnectedDrives() {
        var items = [
            SidebarItem(name: "Macintosh HD", systemImage: "internaldrive", url: URL(fileURLWithPath: "/"), isEjectable: false)
        ]

        let volumesURL = URL(fileURLWithPath: "/Volumes")
        if let vols = try? FileManager.default.contentsOfDirectory(
            at: volumesURL,
            includingPropertiesForKeys: [.volumeIsRemovableKey, .volumeIsEjectableKey, .volumeIsInternalKey],
            options: [.skipsHiddenFiles]
        ) {
            for vol in vols {
                if vol.lastPathComponent != "Macintosh HD" {
                    let vals = try? vol.resourceValues(forKeys: [.volumeIsRemovableKey, .volumeIsEjectableKey, .volumeIsInternalKey])
                    let isRemovable = vals?.volumeIsRemovable ?? true
                    let isEjectable = vals?.volumeIsEjectable ?? true
                    let isInternal = vals?.volumeIsInternal ?? false
                    let canEject = (isRemovable || isEjectable || !isInternal) && vol.path != "/"

                    items.append(SidebarItem(
                        name: vol.lastPathComponent,
                        systemImage: canEject ? "externaldrive.badge.wifi" : "externaldrive",
                        url: vol,
                        isEjectable: canEject
                    ))
                }
            }
        }

        if self.locations != items {
            withAnimation(.easeInOut(duration: 0.2)) {
                self.locations = items
            }
        }
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
            case .kind:
                comparison = lhs.kindDescription.localizedStandardCompare(rhs.kindDescription)
            case .size:
                comparison = lhs.size < rhs.size ? .orderedAscending : (lhs.size > rhs.size ? .orderedDescending : .orderedSame)
            case .dateCreated:
                let lDate = lhs.dateCreated ?? Date.distantPast
                let rDate = rhs.dateCreated ?? Date.distantPast
                comparison = lDate.compare(rDate)
            case .dateModified:
                let lDate = lhs.dateModified ?? Date.distantPast
                let rDate = rhs.dateModified ?? Date.distantPast
                comparison = lDate.compare(rDate)
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

        // Clean previews older than 14 days
        ThumbnailService.shared.cleanOldPreviews(maxAgeInDays: 14)
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
            searchPercentage = 0.0
            return
        }

        isSearching = true
        searchResults = []
        scannedCount = 0
        searchPercentage = 0.0

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
                        self?.searchPercentage = progress.percentage
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

            self.searchPercentage = 100.0
            self.isSearching = false
        }
    }

    // MARK: - Eject Volume (5 attempts with 200ms delay)
    public func ejectVolume(at url: URL) {
        Task {
            var success = false
            for attempt in 1...5 {
                do {
                    try NSWorkspace.shared.unmountAndEjectDevice(at: url)
                    success = true
                    print("[FinderPlus] Successfully ejected \(url.path) on attempt \(attempt)")
                    break
                } catch {
                    print("[FinderPlus] Eject attempt \(attempt) failed for \(url.path): \(error)")
                    if attempt < 5 {
                        try? await Task.sleep(nanoseconds: 200_000_000) // 200ms delay
                    }
                }
            }

            if !success {
                for attempt in 1...5 {
                    let process = Process()
                    process.executableURL = URL(fileURLWithPath: "/usr/sbin/diskutil")
                    process.arguments = ["eject", url.path]
                    try? process.run()
                    process.waitUntilExit()
                    if process.terminationStatus == 0 {
                        success = true
                        print("[FinderPlus] Successfully ejected via diskutil on attempt \(attempt)")
                        break
                    }
                    if attempt < 5 {
                        try? await Task.sleep(nanoseconds: 200_000_000) // 200ms delay
                    }
                }
            }

            await MainActor.run {
                if success {
                    self.updateConnectedDrives()
                    if self.currentDirectory.path == url.path || self.currentDirectory.path.hasPrefix(url.path + "/") {
                        self.navigateTo(url: FileManager.default.homeDirectoryForCurrentUser)
                    }
                }
            }
        }
    }

    // MARK: - Load All Previews for Folder
    public func loadAllPreviews(for folderURL: URL, recursive: Bool = true) {
        let name = folderURL.lastPathComponent.isEmpty ? "Macintosh HD" : folderURL.lastPathComponent
        self.statusMessage = "Loading previews for \"\(name)\"..."
        ThumbnailService.shared.preloadPreviewsForFolder(at: folderURL, recursive: recursive) { [weak self] done, total in
            Task { @MainActor in
                if done >= total {
                    self?.statusMessage = "Loaded \(total) previews for \"\(name)\""
                    DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
                        self?.statusMessage = nil
                    }
                } else if done % 5 == 0 {
                    self?.statusMessage = "Loading previews: \(done)/\(total)..."
                }
            }
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
        selectedItemIDs.subtract(items.map { $0.id })
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
