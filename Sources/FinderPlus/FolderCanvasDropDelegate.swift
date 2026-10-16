import SwiftUI
import UniformTypeIdentifiers

public struct FolderCanvasDropDelegate: DropDelegate {
    public let viewModel: ExplorerViewModel

    public init(viewModel: ExplorerViewModel) {
        self.viewModel = viewModel
    }

    public func validateDrop(info: DropInfo) -> Bool {
        // If dragging an item that is already in this directory, reject dropping it back onto the same canvas.
        // This causes macOS to smoothly fly the drag preview image back to the original file's position!
        if let draggingID = viewModel.draggingItemID,
           viewModel.folderItems.contains(where: { $0.id == draggingID }) {
            return false
        }
        return info.hasItemsConforming(to: [.fileURL, .url])
    }

    public func dropUpdated(info: DropInfo) -> DropProposal? {
        if let draggingID = viewModel.draggingItemID,
           viewModel.folderItems.contains(where: { $0.id == draggingID }) {
            // Reject drop -> triggers native fly-back animation on release!
            return nil
        }
        return DropProposal(operation: .move)
    }

    public func performDrop(info: DropInfo) -> Bool {
        if let draggingID = viewModel.draggingItemID,
           viewModel.folderItems.contains(where: { $0.id == draggingID }) {
            return false
        }

        let providers = info.itemProviders(for: [.fileURL, .url])
        guard !providers.isEmpty else { return false }

        for provider in providers {
            _ = provider.loadObject(ofClass: NSURL.self) { nsURL, _ in
                if let url = nsURL as? URL {
                    Task { @MainActor in
                        viewModel.handleDrop(urls: [url], targetDirectory: viewModel.currentDirectory)
                    }
                }
            }
        }
        return true
    }
}
