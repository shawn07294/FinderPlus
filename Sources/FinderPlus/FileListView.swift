import SwiftUI
import AppKit

public struct FileListView: View {
    @ObservedObject var viewModel: ExplorerViewModel
    @State private var itemToRename: FileItem?
    @State private var newNameInput: String = ""
    @State private var showRenameAlert: Bool = false
    @State private var itemFrames: [String: CGRect] = [:]
    @State private var rubberBandStart: CGPoint? = nil
    @State private var rubberBandCurrent: CGPoint? = nil
    @State private var preRubberBandSelection: Set<String> = []

    private var rubberBandRect: CGRect? {
        guard let start = rubberBandStart, let current = rubberBandCurrent else { return nil }
        return CGRect(
            x: min(start.x, current.x),
            y: min(start.y, current.y),
            width: abs(current.x - start.x),
            height: abs(current.y - start.y)
        )
    }

    public var body: some View {
        VStack(spacing: 0) {
            // Table Header
            HStack(spacing: 0) {
                headerButton(title: "Name", field: .name)
                    .frame(maxWidth: .infinity, alignment: .leading)

                Divider().frame(height: 14)

                headerButton(title: "Date Modified", field: .dateModified)
                    .frame(width: max(140, 160 * viewModel.appScale), alignment: .leading)
                    .padding(.horizontal, 8)

                Divider().frame(height: 14)

                headerButton(title: "Size", field: .size)
                    .frame(width: max(85, 105 * viewModel.appScale), alignment: .trailing)
                    .padding(.leading, 8)
                    .padding(.trailing, 20)

                Divider().frame(height: 14)

                headerButton(title: "Kind", field: .kind)
                    .frame(width: max(120, 150 * viewModel.appScale), alignment: .leading)
                    .padding(.leading, 12)
            }
            .font(.system(size: 11 * viewModel.appScale, weight: .medium))
            .foregroundColor(.secondary)
            .padding(.horizontal, 16)
            .frame(height: max(24, 28 * viewModel.appScale))
            .background(Color(NSColor.controlBackgroundColor))

            Divider()

            // File Rows with rubber band selection
            GeometryReader { geometry in
                ScrollView {
                    ZStack(alignment: .topLeading) {
                        VStack(spacing: 0) {
                            LazyVStack(spacing: 0) {
                                ForEach(viewModel.displayedItems) { item in
                                    FileListRow(item: item, viewModel: viewModel)
                                        .background(
                                            GeometryReader { itemGeo in
                                                Color.clear.preference(
                                                    key: ItemFramePreferenceKey.self,
                                                    value: [item.id: itemGeo.frame(in: .named("listScrollContent"))]
                                                )
                                            }
                                        )
                                }
                            }

                            // Empty space below files - clicking here unselects everything
                            Color.clear
                                .frame(maxWidth: .infinity)
                                .frame(minHeight: max(50, geometry.size.height - CGFloat(viewModel.displayedItems.count * 28)))
                                .contentShape(Rectangle())
                                .contextMenu {
                                    Menu("Load All Previews") {
                                        Button("entire drive (including subfolders)") {
                                            viewModel.loadAllPreviews(for: viewModel.currentDirectory, recursive: true)
                                        }
                                        Button("this folder only") {
                                            viewModel.loadAllPreviews(for: viewModel.currentDirectory, recursive: false)
                                        }
                                    }
                                    Divider()
                                    Button("New Folder") {
                                        viewModel.createNewFolder()
                                    }
                                }
                        }
                        .onPreferenceChange(ItemFramePreferenceKey.self) { frames in
                            itemFrames = frames
                        }

                        // Rubber band rectangle overlay
                        if let rect = rubberBandRect, rect.width > 2 || rect.height > 2 {
                            Rectangle()
                                .fill(Color.accentColor.opacity(0.12))
                                .overlay(
                                    Rectangle()
                                        .stroke(Color.accentColor.opacity(0.55), lineWidth: 1)
                                )
                                .frame(width: rect.width, height: rect.height)
                                .offset(x: rect.origin.x, y: rect.origin.y)
                                .allowsHitTesting(false)
                        }
                    }
                    .coordinateSpace(name: "listScrollContent")
                    .contentShape(Rectangle())
                    .gesture(
                        DragGesture(minimumDistance: 4, coordinateSpace: .named("listScrollContent"))
                            .onChanged { value in
                                if rubberBandStart == nil {
                                    rubberBandStart = value.startLocation
                                    // Preserve existing selection if shift/cmd held
                                    let flags = NSEvent.modifierFlags
                                    if flags.contains(.shift) || flags.contains(.command) {
                                        preRubberBandSelection = viewModel.selectedItemIDs
                                    } else {
                                        preRubberBandSelection = []
                                    }
                                }
                                rubberBandCurrent = value.location

                                // Update selection based on intersection
                                if let rect = rubberBandRect {
                                    var newSelection = preRubberBandSelection
                                    for (id, frame) in itemFrames {
                                        if rect.intersects(frame) {
                                            newSelection.insert(id)
                                        }
                                    }
                                    viewModel.selectedItemIDs = newSelection
                                }
                            }
                            .onEnded { _ in
                                rubberBandStart = nil
                                rubberBandCurrent = nil
                            }
                    )
                    .onTapGesture {
                        let flags = NSEvent.modifierFlags
                        if !flags.contains(.shift) && !flags.contains(.command) {
                            viewModel.selectedItemIDs.removeAll()
                        }
                    }
                }
                .onDrop(of: [.fileURL, .url], delegate: FolderCanvasDropDelegate(viewModel: viewModel))
            }
        }
        .alert("Rename Item", isPresented: $showRenameAlert) {
            TextField("New Name", text: $newNameInput)
            Button("Cancel", role: .cancel) {}
            Button("Rename") {
                if let target = itemToRename {
                    viewModel.renameItem(target, to: newNameInput)
                }
            }
        } message: {
            Text("Enter a new name for \"\(itemToRename?.name ?? "")\":")
        }
    }

    private func headerButton(title: String, field: SortField) -> some View {
        Button(action: {
            if viewModel.sortField == field {
                viewModel.sortAscending.toggle()
            } else {
                viewModel.sortField = field
                viewModel.sortAscending = true
            }
        }) {
            HStack(spacing: 4) {
                Text(title)
                if viewModel.sortField == field {
                    Image(systemName: viewModel.sortAscending ? "chevron.up" : "chevron.down")
                        .font(.system(size: 9, weight: .bold))
                }
            }
            .padding(.horizontal, 6)
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private func contextMenu(for item: FileItem) -> some View {
        Button("Open") {
            viewModel.openItem(item)
        }
        Button("Quick Look") {
            viewModel.toggleQuickLook(for: item)
        }
        Divider()
        Button("Reveal in Finder") {
            viewModel.revealInFinder(item)
        }
        Button("Copy Path") {
            viewModel.copyPath(item)
        }
        Button("Duplicate") {
            viewModel.duplicateItem(item)
        }
        Divider()
        Button("Rename...") {
            itemToRename = item
            newNameInput = item.name
            showRenameAlert = true
        }
        Button("Move to Trash", role: .destructive) {
            viewModel.moveToTrash([item])
        }
    }
}

private struct FileListRow: View {
    let item: FileItem
    @ObservedObject var viewModel: ExplorerViewModel
    @State private var isTargeted: Bool = false
    @State private var lastClickTime: TimeInterval = 0
    @State private var itemToRename: FileItem?
    @State private var newNameInput: String = ""
    @State private var showRenameAlert: Bool = false

    private var isSelected: Bool {
        viewModel.selectedItemIDs.contains(item.id)
    }

    private var isDraggingThisItem: Bool {
        viewModel.draggingItemID == item.id
    }

    private var iconSize: CGFloat {
        18 * viewModel.iconScale
    }

    var body: some View {
        HStack(spacing: 0) {
            // Name & Icon
            HStack(spacing: 8) {
                HStack(spacing: 8) {
                    FileThumbnailView(item: item, size: iconSize)
                        .opacity(isDraggingThisItem ? 0.45 : 1.0)

                    Text(item.name)
                        .font(.system(size: 13 * viewModel.appScale))
                        .lineLimit(1)
                        .truncationMode(.middle)
                        .foregroundColor(isSelected ? .white : (item.isHidden ? .secondary : .primary))
                        .opacity(isDraggingThisItem ? 0.45 : 1.0)
                }
                .contentShape(Rectangle())
                .draggable(item.url) {
                    HStack(spacing: 8) {
                        FileThumbnailView(item: item, size: iconSize)
                        Text(item.name)
                            .font(.system(size: 11 * viewModel.appScale))
                            .lineLimit(1)
                    }
                    .padding(.horizontal, 6)
                    .padding(.vertical, 3)
                    .background(Color(NSColor.windowBackgroundColor))
                    .cornerRadius(4)
                    .onAppear {
                        viewModel.draggingItemID = item.id
                        viewModel.selectedItemIDs = [item.id]
                    }
                }

                Spacer(minLength: 0)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            // Date Modified
            Text(item.formattedDate)
                .font(.system(size: 11 * viewModel.appScale))
                .foregroundColor(isSelected ? .white.opacity(0.9) : .secondary)
                .opacity(isDraggingThisItem ? 0.45 : 1.0)
                .frame(width: max(140, 160 * viewModel.appScale), alignment: .leading)
                .padding(.horizontal, 8)

            // Size (spread out with 20pt trailing padding)
            Text(item.formattedSize)
                .font(.system(size: 11 * viewModel.appScale))
                .foregroundColor(isSelected ? .white.opacity(0.9) : .secondary)
                .opacity(isDraggingThisItem ? 0.45 : 1.0)
                .frame(width: max(85, 105 * viewModel.appScale), alignment: .trailing)
                .padding(.leading, 8)
                .padding(.trailing, 20)

            // Kind (spread out with 12pt leading padding)
            Text(item.kindDescription)
                .font(.system(size: 11 * viewModel.appScale))
                .foregroundColor(isSelected ? .white.opacity(0.9) : .secondary)
                .opacity(isDraggingThisItem ? 0.45 : 1.0)
                .frame(width: max(120, 150 * viewModel.appScale), alignment: .leading)
                .padding(.leading, 12)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, max(3, 5 * viewModel.iconScale))
        .background(
            isTargeted
                ? Color.accentColor.opacity(0.35)
                : isDraggingThisItem
                    ? Color.accentColor.opacity(0.3)
                    : (isSelected ? Color.accentColor : Color.clear)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 4)
                .stroke(isTargeted ? Color.accentColor : Color.clear, lineWidth: 2)
        )
        .contentShape(Rectangle())
        .onTapGesture {
            let now = ProcessInfo.processInfo.systemUptime
            let flags = NSEvent.modifierFlags
            if isSelected && (now - lastClickTime) < NSEvent.doubleClickInterval && !flags.contains(.shift) && !flags.contains(.command) {
                viewModel.openItem(item)
            } else {
                viewModel.selectItem(item, shiftHeld: flags.contains(.shift), cmdHeld: flags.contains(.command))
            }
            lastClickTime = now
        }
        .modifier(FolderDropDestinationModifier(item: item, viewModel: viewModel, isTargeted: $isTargeted, onDropCompleted: {
            viewModel.draggingItemID = nil
        }))
        .contextMenu {
            Button("Open") {
                viewModel.openItem(item)
            }
            Button("Quick Look") {
                viewModel.toggleQuickLook(for: item)
            }
            Divider()
            Button("Reveal in Finder") {
                viewModel.revealInFinder(item)
            }
            Button("Copy Path") {
                viewModel.copyPath(item)
            }
            Button("Duplicate") {
                viewModel.duplicateItem(item)
            }
            if item.isDirectory {
                Divider()
                Menu("Load All Previews") {
                    Button("entire drive (including subfolders)") {
                        viewModel.loadAllPreviews(for: item.url, recursive: true)
                    }
                    Button("this folder only") {
                        viewModel.loadAllPreviews(for: item.url, recursive: false)
                    }
                }
            }
            Divider()
            Button("Rename...") {
                itemToRename = item
                newNameInput = item.name
                showRenameAlert = true
            }
            Button("Move to Trash", role: .destructive) {
                viewModel.moveToTrash([item])
            }
        }
        .alert("Rename Item", isPresented: $showRenameAlert) {
            TextField("New Name", text: $newNameInput)
            Button("Cancel", role: .cancel) {}
            Button("Rename") {
                if let target = itemToRename {
                    viewModel.renameItem(target, to: newNameInput)
                }
            }
        } message: {
            Text("Enter a new name for \"\(itemToRename?.name ?? "")\":")
        }
    }
}

public struct FolderDropDestinationModifier: ViewModifier {
    let item: FileItem
    @ObservedObject var viewModel: ExplorerViewModel
    @Binding var isTargeted: Bool
    var onDropCompleted: (() -> Void)? = nil

    public func body(content: Content) -> some View {
        if item.isDirectory {
            content
                .dropDestination(for: URL.self) { urls, _ in
                    let result = viewModel.handleDrop(urls: urls, targetDirectory: item.url)
                    onDropCompleted?()
                    return result
                } isTargeted: { targeted in
                    isTargeted = targeted
                }
        } else {
            content
        }
    }
}

