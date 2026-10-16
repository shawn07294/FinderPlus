import SwiftUI
import AppKit

public struct FileIconView: View {
    @ObservedObject var viewModel: ExplorerViewModel

    private var columns: [GridItem] {
        let minW = 96 * viewModel.iconScale
        let maxW = 130 * viewModel.iconScale
        return [
            GridItem(.adaptive(minimum: minW, maximum: maxW), spacing: 16 * viewModel.iconScale)
        ]
    }

    public var body: some View {
        ScrollView {
            LazyVGrid(columns: columns, spacing: 20 * viewModel.iconScale) {
                ForEach(viewModel.displayedItems) { item in
                    FileIconCell(item: item, viewModel: viewModel)
                }
            }
            .padding(20)
        }
        .background(Color(NSColor.textBackgroundColor))
        .onDrop(of: [.fileURL, .url], delegate: FolderCanvasDropDelegate(viewModel: viewModel))
    }
}

private struct FileIconCell: View {
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

    private var scale: Double {
        viewModel.iconScale
    }

    var body: some View {
        VStack(spacing: 6 * scale) {
            // Prioritized rich image & document preview thumbnail
            FileThumbnailView(item: item, size: 56 * scale)
                .shadow(color: .black.opacity(0.15), radius: 2, y: 1)
                .opacity(isDraggingThisItem ? 0.45 : 1.0)

            Text(item.name)
                .font(.system(size: max(9, min(16, 11 * scale)), weight: .medium))
                .lineLimit(2)
                .multilineTextAlignment(.center)
                .foregroundColor(.white)
                .padding(.horizontal, 6)
                .padding(.vertical, 3)
                .background(
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color(white: 0.16, opacity: 0.95))
                )
                .opacity(isDraggingThisItem ? 0.55 : 1.0)
        }
        .frame(width: 96 * scale, height: 104 * scale)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(
                    isTargeted
                        ? Color.accentColor.opacity(0.25)
                        : isDraggingThisItem
                            ? Color.accentColor.opacity(0.12)
                            : isSelected
                                ? Color(white: 0.28, opacity: 0.50)
                                : Color.clear
                )
        )
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(
                    isTargeted
                        ? Color.accentColor
                        : isDraggingThisItem
                            ? Color(white: 0.20, opacity: 0.90)
                            : isSelected
                                ? Color(white: 0.20, opacity: 0.85)
                                : Color.clear,
                    lineWidth: isTargeted ? 2 : 1.5
                )
        )
        .clipShape(RoundedRectangle(cornerRadius: 8))
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
        .draggable(item.url) {
            // High-resolution, stable drag preview that follows the mouse cleanly
            VStack(spacing: 4) {
                FileThumbnailView(item: item, size: 48)
                Text(item.name)
                    .font(.system(size: 10, weight: .medium))
                    .lineLimit(1)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(
                        RoundedRectangle(cornerRadius: 4)
                            .fill(Color(white: 0.16, opacity: 0.95))
                    )
                    .foregroundColor(.white)
            }
            .padding(6)
            .onAppear {
                viewModel.draggingItemID = item.id
                viewModel.selectedItemIDs = [item.id]
            }
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
