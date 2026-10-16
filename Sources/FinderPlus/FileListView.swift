import SwiftUI
import AppKit

public struct FileListView: View {
    @ObservedObject var viewModel: ExplorerViewModel
    @State private var itemToRename: FileItem?
    @State private var newNameInput: String = ""
    @State private var showRenameAlert: Bool = false

    public var body: some View {
        VStack(spacing: 0) {
            // Table Header
            HStack(spacing: 0) {
                headerButton(title: "Name", field: .name)
                    .frame(minWidth: 220, alignment: .leading)

                Divider()

                headerButton(title: "Date Modified", field: .dateModified)
                    .frame(width: 160, alignment: .leading)

                Divider()

                headerButton(title: "Size", field: .size)
                    .frame(width: 100, alignment: .trailing)

                Divider()

                headerButton(title: "Kind", field: .kind)
                    .frame(width: 140, alignment: .leading)
            }
            .font(.caption.weight(.medium))
            .foregroundColor(.secondary)
            .padding(.horizontal, 16)
            .frame(height: 26)
            .background(Color(NSColor.controlBackgroundColor))

            Divider()

            // File Rows
            GeometryReader { geometry in
                ScrollView {
                    VStack(spacing: 0) {
                        LazyVStack(spacing: 0) {
                            ForEach(viewModel.displayedItems) { item in
                                FileListRow(item: item, viewModel: viewModel)
                            }
                        }

                        // Empty space below files - clicking here unselects everything
                        Color.clear
                            .frame(maxWidth: .infinity)
                            .frame(minHeight: max(50, geometry.size.height - CGFloat(viewModel.displayedItems.count * 28)))
                            .contentShape(Rectangle())
                            .onTapGesture {
                                viewModel.selectedItemIDs.removeAll()
                            }
                    }
                }
                .contentShape(Rectangle())
                .onTapGesture {
                    viewModel.selectedItemIDs.removeAll()
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
                            .font(.caption)
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
            .frame(minWidth: 220, alignment: .leading)

            // Date Modified
            Text(item.formattedDate)
                .font(.caption)
                .foregroundColor(isSelected ? .white.opacity(0.9) : .secondary)
                .opacity(isDraggingThisItem ? 0.45 : 1.0)
                .frame(width: 160, alignment: .leading)

            // Size
            Text(item.formattedSize)
                .font(.caption)
                .foregroundColor(isSelected ? .white.opacity(0.9) : .secondary)
                .opacity(isDraggingThisItem ? 0.45 : 1.0)
                .frame(width: 100, alignment: .trailing)

            // Kind
            Text(item.kindDescription)
                .font(.caption)
                .foregroundColor(isSelected ? .white.opacity(0.9) : .secondary)
                .opacity(isDraggingThisItem ? 0.45 : 1.0)
                .frame(width: 140, alignment: .leading)
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
            if isSelected && (now - lastClickTime) < NSEvent.doubleClickInterval {
                viewModel.openItem(item)
            } else {
                viewModel.selectedItemIDs = [item.id]
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

