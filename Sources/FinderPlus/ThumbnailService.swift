import Foundation
import AppKit
import QuickLookThumbnailing
import UniformTypeIdentifiers
import CryptoKit

public final class ThumbnailService: @unchecked Sendable {
    public static let shared = ThumbnailService()

    private let memoryCache = NSCache<NSString, NSImage>()
    private let fileManager = FileManager.default
    private let cacheDirectoryURL: URL

    // Extensions that benefit from prioritized rich thumbnail previews
    private let previewExtensions: Set<String> = [
        // Images
        "jpg", "jpeg", "png", "heic", "heif", "gif", "tiff", "tif", "webp", "bmp", "ico", "svg", "raw", "cr2", "nef", "arw", "dng",
        // Documents & PDFs
        "pdf", "pages", "numbers", "key", "ai", "psd",
        // Videos
        "mov", "mp4", "m4v", "mkv", "avi"
    ]

    private init() {
        memoryCache.countLimit = 600

        // Disk cache directory: ~/Library/Caches/FinderPlus/Thumbnails
        let paths = fileManager.urls(for: .cachesDirectory, in: .userDomainMask)
        let baseCache = paths.first ?? URL(fileURLWithPath: NSTemporaryDirectory())
        self.cacheDirectoryURL = baseCache.appendingPathComponent("FinderPlus/Thumbnails", isDirectory: true)

        try? fileManager.createDirectory(at: cacheDirectoryURL, withIntermediateDirectories: true)

        // Automatically clean preview files older than a week (7 days) on launch
        cleanOldPreviews(maxAgeInDays: 7)
    }

    /// Whether this file item should be prioritized for rich thumbnail generation
    public func isPreviewEligible(item: FileItem) -> Bool {
        guard !item.isDirectory else { return false }
        return previewExtensions.contains(item.fileExtension)
    }

    /// Retrieve cached thumbnail or standard system icon immediately
    public func cachedThumbnail(for item: FileItem, size: CGFloat = 128) -> NSImage? {
        let keyString = diskKey(for: item, size: size)
        if let memoryImg = memoryCache.object(forKey: keyString as NSString) {
            return memoryImg
        }
        let diskURL = cacheDirectoryURL.appendingPathComponent(keyString)
        if let data = try? Data(contentsOf: diskURL), let diskImg = NSImage(data: data) {
            memoryCache.setObject(diskImg, forKey: keyString as NSString)
            return diskImg
        }
        return nil
    }

    /// Prioritized async thumbnail loader: returns cached image or generates one asynchronously
    public func loadThumbnail(
        for item: FileItem,
        targetSize: CGFloat = 128,
        completion: @escaping @Sendable (NSImage) -> Void
    ) {
        let keyString = diskKey(for: item, size: targetSize)

        // 1. Instant Memory Cache check
        if let inMemory = memoryCache.object(forKey: keyString as NSString) {
            completion(inMemory)
            return
        }

        // 2. High-priority asynchronous background task
        Task.detached(priority: .userInitiated) { [weak self] in
            guard let self = self else { return }

            // Check Disk Cache
            let diskURL = self.cacheDirectoryURL.appendingPathComponent(keyString)
            if let data = try? Data(contentsOf: diskURL), let diskImg = NSImage(data: data) {
                self.memoryCache.setObject(diskImg, forKey: keyString as NSString)
                await MainActor.run { completion(diskImg) }
                return
            }

            // 3. Generate high-resolution thumbnail via QLThumbnailGenerator
            let request = QLThumbnailGenerator.Request(
                fileAt: item.url,
                size: CGSize(width: targetSize, height: targetSize),
                scale: 2.0,
                representationTypes: .thumbnail
            )

            do {
                let thumbnail = try await QLThumbnailGenerator.shared.generateBestRepresentation(for: request)
                let image = thumbnail.nsImage
                self.memoryCache.setObject(image, forKey: keyString as NSString)
                self.saveThumbnailToDisk(image: image, fileURL: diskURL)
                await MainActor.run { completion(image) }
            } catch {
                let fallback = IconCache.shared.icon(for: item.url.path)
                await MainActor.run { completion(fallback) }
            }
        }
    }

    private func saveThumbnailToDisk(image: NSImage, fileURL: URL) {
        guard let tiffData = image.tiffRepresentation,
              let rep = NSBitmapImageRep(data: tiffData),
              let jpegData = rep.representation(using: .jpeg, properties: [.compressionFactor: 0.82]) else {
            return
        }
        try? jpegData.write(to: fileURL, options: .atomic)
    }

    private func diskKey(for item: FileItem, size: CGFloat) -> String {
        let modTime = item.dateModified?.timeIntervalSince1970 ?? 0
        let raw = "\(item.url.path)_\(modTime)_\(Int(size))"
        let hash = Insecure.MD5.hash(data: Data(raw.utf8))
        return hash.map { String(format: "%02x", $0) }.joined() + ".thumb"
    }

    // MARK: - Weekly Cache Cleanup (Delete preview files older than a week)

    /// Deletes all cached preview files older than `maxAgeInDays` (default 7 days)
    public func cleanOldPreviews(maxAgeInDays: Int = 7) {
        Task.detached(priority: .background) { [weak self] in
            guard let self = self else { return }
            let cutoffDate = Date().addingTimeInterval(-Double(maxAgeInDays * 86400))
            let keys: [URLResourceKey] = [.contentModificationDateKey, .fileSizeKey]

            guard let enumerator = self.fileManager.enumerator(
                at: self.cacheDirectoryURL,
                includingPropertiesForKeys: keys,
                options: [.skipsHiddenFiles]
            ) else { return }

            var deletedCount = 0
            var reclaimedBytes: Int64 = 0

            while let fileURL = enumerator.nextObject() as? URL {
                if let values = try? fileURL.resourceValues(forKeys: Set(keys)),
                   let modDate = values.contentModificationDate {
                    if modDate < cutoffDate {
                        let size = Int64(values.fileSize ?? 0)
                        if (try? self.fileManager.removeItem(at: fileURL)) != nil {
                            deletedCount += 1
                            reclaimedBytes += size
                        }
                    }
                }
            }

            if deletedCount > 0 {
                let formatted = ByteCountFormatter.string(fromByteCount: reclaimedBytes, countStyle: .file)
                print("[FinderPlus] Cleaned \(deletedCount) preview files older than \(maxAgeInDays) days (reclaimed \(formatted)).")
            }
        }
    }

    // MARK: - Cache Size Statistics

    public struct CacheStatistics: Sendable {
        public let fileCount: Int
        public let totalBytes: Int64
        public let averageFileBytes: Int64

        public var formattedTotalSize: String {
            ByteCountFormatter.string(fromByteCount: totalBytes, countStyle: .file)
        }

        public var formattedAverageSize: String {
            ByteCountFormatter.string(fromByteCount: averageFileBytes, countStyle: .file)
        }
    }

    /// Calculates current disk cache size and item count
    public func getCacheStatistics() -> CacheStatistics {
        let keys: [URLResourceKey] = [.fileSizeKey]
        guard let files = try? fileManager.contentsOfDirectory(
            at: cacheDirectoryURL,
            includingPropertiesForKeys: keys,
            options: [.skipsHiddenFiles]
        ) else {
            return CacheStatistics(fileCount: 0, totalBytes: 0, averageFileBytes: 0)
        }

        var count = 0
        var total: Int64 = 0

        for file in files {
            if let vals = try? file.resourceValues(forKeys: Set(keys)), let s = vals.fileSize {
                count += 1
                total += Int64(s)
            }
        }

        let avg = count > 0 ? (total / Int64(count)) : 0
        return CacheStatistics(fileCount: count, totalBytes: total, averageFileBytes: avg)
    }
}
