import Foundation
import AppKit
import UniformTypeIdentifiers

public final class IconCache: @unchecked Sendable {
    public static let shared = IconCache()
    private let cache = NSCache<NSString, NSImage>()

    public func icon(for path: String) -> NSImage {
        let key = path as NSString
        if let cached = cache.object(forKey: key) {
            return cached
        }
        let image = NSWorkspace.shared.icon(forFile: path)
        cache.setObject(image, forKey: key)
        return image
    }
}

public struct FileItem: Identifiable, Hashable, Sendable {
    public var id: String { url.path }
    public let url: URL
    public let name: String
    public let isDirectory: Bool
    public let isPackage: Bool
    public let isHidden: Bool
    public let size: Int64
    public let dateModified: Date?
    public let kindDescription: String
    public let fileExtension: String

    private static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter
    }()

    public init(url: URL) {
        self.url = url
        self.name = url.lastPathComponent
        self.fileExtension = url.pathExtension.lowercased()

        let values = try? url.resourceValues(forKeys: [
            .isDirectoryKey,
            .isPackageKey,
            .isHiddenKey,
            .fileSizeKey,
            .contentModificationDateKey,
            .contentTypeKey,
            .localizedTypeDescriptionKey
        ])

        let isDir = values?.isDirectory ?? false
        let isPkg = values?.isPackage ?? false
        self.isDirectory = isDir && !isPkg
        self.isPackage = isPkg
        self.isHidden = values?.isHidden ?? url.lastPathComponent.hasPrefix(".")
        self.size = Int64(values?.fileSize ?? 0)
        self.dateModified = values?.contentModificationDate

        if let desc = values?.localizedTypeDescription {
            self.kindDescription = desc
        } else if isDir && !isPkg {
            self.kindDescription = "Folder"
        } else if let contentType = values?.contentType {
            self.kindDescription = contentType.localizedDescription ?? contentType.preferredFilenameExtension?.uppercased() ?? "Document"
        } else if !url.pathExtension.isEmpty {
            self.kindDescription = "\(url.pathExtension.uppercased()) File"
        } else {
            self.kindDescription = isDir ? "Folder" : "Document"
        }
    }

    public init(
        url: URL,
        name: String,
        isDirectory: Bool,
        isPackage: Bool,
        isHidden: Bool,
        size: Int64,
        dateModified: Date?,
        kindDescription: String
    ) {
        self.url = url
        self.name = name
        self.fileExtension = url.pathExtension.lowercased()
        self.isDirectory = isDirectory
        self.isPackage = isPackage
        self.isHidden = isHidden
        self.size = size
        self.dateModified = dateModified
        self.kindDescription = kindDescription
    }

    public var formattedSize: String {
        if isDirectory {
            return "--"
        }
        return ByteCountFormatter.string(fromByteCount: size, countStyle: .file)
    }

    public var formattedDate: String {
        guard let date = dateModified else { return "--" }
        return Self.dateFormatter.string(from: date)
    }

    public var icon: NSImage {
        IconCache.shared.icon(for: url.path)
    }
}
