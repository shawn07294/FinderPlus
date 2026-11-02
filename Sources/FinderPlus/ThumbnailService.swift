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

    private let previewExtensions: Set<String> = [
        "jpg", "jpeg", "png", "heic", "heif", "gif", "tiff", "tif", "webp", "bmp", "ico", "svg", "raw", "cr2", "nef", "arw", "dng",
        "pdf", "pages", "numbers", "key", "ai", "psd",
        "mov", "mp4", "m4v", "mkv", "avi"
    ]

    private init() {
        memoryCache.countLimit = 600

        // v1.2.0M preview storage. The released app is installed at
        // /Applications/FinderPlus.app, so generated previews live in
        // /Applications/FinderPlus.app/Contents/PREVIEWS.
        self.cacheDirectoryURL = URL(fileURLWithPath: "/Applications/FinderPlus.app/Contents/PREVIEWS", isDirectory: true)

        do {
            try fileManager.createDirectory(at: cacheDirectoryURL, withIntermediateDirectories: true)
        } catch {
            print("[FinderPlus] Unable to create PREVIEWS directory: \(error)")
        }

        cleanOldPreviews(maxAgeInDays: 3)
    }

    public func isPreviewEligible(item: FileItem) -> Bool {
        guard !item.isDirectory else { return false }
        return previewExtensions.contains(item.fileExtension.lowercased())
    }

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

    public func loadThumbnail(
        for item: FileItem,
        targetSize: CGFloat = 128,
        completion: @escaping @Sendable (NSImage) -> Void
    ) {
        let keyString = diskKey(for: item, size: targetSize)

        if let inMemory = memoryCache.object(forKey: keyString as NSString) {
            completion(inMemory)
            return
        }

        Task.detached(priority: .userInitiated) { [weak self] in
            guard let self = self else { return }

            let diskURL = self.cacheDirectoryURL.appendingPathComponent(keyString)
            if let data = try? Data(contentsOf: diskURL), let diskImg = NSImage(data: data) {
                self.memoryCache.setObject(diskImg, forKey: keyString as NSString)
                await MainActor.run { completion(diskImg) }
                return
            }

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

    /// Pre-generate thumbnails for all eligible files in the current folder.
    /// Four Quick Look jobs are allowed at once to avoid overwhelming the UI or disk.
    public func preloadThumbnails(for items: [FileItem], targetSize: CGFloat = 128) {
        let eligibleItems = items.filter { isPreviewEligible(item: $0) }
        guard !eligibleItems.isEmpty else { return }

        Task.detached(priority: .utility) { [weak self] in
            guard let self = self else { return }
            let concurrency = 4
            var index = 0

            while index < eligibleItems.count {
                if Task.isCancelled { return }
                let end = min(index + concurrency, eligibleItems.count)
                let batch = Array(eligibleItems[index..<end])

                await withTaskGroup(of: Void.self) { group in
                    for item in batch {
                        group.addTask {
                            await self.preloadSingleThumbnail(item: item, targetSize: targetSize)
                        }
                    }
                }
                index = end
            }
        }
    }

    private func preloadSingleThumbnail(item: FileItem, targetSize: CGFloat) async {
        let keyString = diskKey(for: item, size: targetSize)
        if memoryCache.object(forKey: keyString as NSString) != nil { return }

        let diskURL = cacheDirectoryURL.appendingPathComponent(keyString)
        if let data = try? Data(contentsOf: diskURL), let image = NSImage(data: data) {
            memoryCache.setObject(image, forKey: keyString as NSString)
            return
        }

        let request = QLThumbnailGenerator.Request(
            fileAt: item.url,
            size: CGSize(width: targetSize, height: targetSize),
            scale: 2.0,
            representationTypes: .thumbnail
        )

        do {
            let thumbnail = try await QLThumbnailGenerator.shared.generateBestRepresentation(for: request)
            let image = thumbnail.nsImage
            memoryCache.setObject(image, forKey: keyString as NSString)
            saveThumbnailToDisk(image: image, fileURL: diskURL)
        } catch {
            // A failed preview must not prevent the remaining folder from loading.
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

    // MARK: - Three-Day Cache Cleanup

    public func cleanOldPreviews(maxAgeInDays: Int = 3) {
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
                   let modDate = values.contentModificationDate,
                   modDate < cutoffDate {
                    let size = Int64(values.fileSize ?? 0)
                    if (try? self.fileManager.removeItem(at: fileURL)) != nil {
                        deletedCount += 1
                        reclaimedBytes += size
                    }
                }
            }

            if deletedCount > 0 {
                let formatted = ByteCountFormatter.string(fromByteCount: reclaimedBytes, countStyle: .file)
                print("[FinderPlus] Cleaned \(deletedCount) preview files older than \(maxAgeInDays) days (reclaimed \(formatted)).")
            }
        }
    }

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
            if let vals = try? file.resourceValues(forKeys: Set(keys)), let size = vals.fileSize {
                count += 1
                total += Int64(size)
            }
        }
        let avg = count > 0 ? total / Int64(count) : 0
        return CacheStatistics(fileCount: count, totalBytes: total, averageFileBytes: avg)
    }
}
