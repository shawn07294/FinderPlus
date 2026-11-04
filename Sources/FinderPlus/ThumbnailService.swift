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
        "jpg", "jpeg", "png", "heic", "heif", "gif", "tiff", "tif", "webp", "bmp", "ico", "svg", "raw", "cr2", "nef", "arw", "dng", "icns", "psd", "ai",
        // Documents & PDFs
        "pdf", "pages", "numbers", "key", "doc", "docx", "xls", "xlsx", "ppt", "pptx", "txt", "rtf", "csv", "json", "md", "html",
        // Videos
        "mov", "mp4", "m4v", "mkv", "avi", "webm", "wmv", "flv",
        // Audio
        "mp3", "m4a", "wav", "flac", "aac", "aiff"
    ]

    private static func resolvePreviewsDirectory() -> URL {
        let fm = FileManager.default
        let bundleURL = Bundle.main.bundleURL
        let contentsPreviews = bundleURL.appendingPathComponent("Contents/PREVIEWS", isDirectory: true)
        let appPreviews = URL(fileURLWithPath: "/Applications/FinderPlus.app/Contents/PREVIEWS")

        if fm.fileExists(atPath: contentsPreviews.path) && fm.isWritableFile(atPath: contentsPreviews.path) {
            return contentsPreviews
        }
        if fm.fileExists(atPath: appPreviews.path) && fm.isWritableFile(atPath: appPreviews.path) {
            return appPreviews
        }
        if (try? fm.createDirectory(at: contentsPreviews, withIntermediateDirectories: true)) != nil {
            return contentsPreviews
        }
        if (try? fm.createDirectory(at: appPreviews, withIntermediateDirectories: true)) != nil {
            return appPreviews
        }
        return contentsPreviews
    }

    private init() {
        memoryCache.countLimit = 600

        // Store all preview files in Contents/PREVIEWS
        self.cacheDirectoryURL = Self.resolvePreviewsDirectory()
        try? fileManager.createDirectory(at: cacheDirectoryURL, withIntermediateDirectories: true)

        // Automatically clean preview files older than 14 days on launch
        cleanOldPreviews(maxAgeInDays: 14)
    }

    /// Whether this file item should be prioritized for rich thumbnail generation
    public func isPreviewEligible(item: FileItem) -> Bool {
        guard !item.isDirectory else { return false }
        return previewExtensions.contains(item.fileExtension)
    }

    /// Candidate disk keys for an item:
    /// 1. Canonical size-independent key
    /// 2. Size 128 key (used by batch preloading and all existing 25k+ preview files)
    /// 3. Requested display size key
    private func candidateDiskKeys(for item: FileItem, size: CGFloat = 128) -> [String] {
        var keys: [String] = []
        let modTime = item.dateModified?.timeIntervalSince1970 ?? 0
        let paths = [item.url.path, item.url.standardizedFileURL.path]

        for p in Set(paths) {
            // 1. Canonical size-independent key
            let rawCanonical = "\(p)_\(modTime)"
            let hashCanonical = Insecure.MD5.hash(data: Data(rawCanonical.utf8)).map { String(format: "%02x", $0) }.joined() + ".thumb"
            keys.append(hashCanonical)

            // 2. Standard 128 key (matches all existing preloaded thumbnails)
            let raw128 = "\(p)_\(modTime)_128"
            let hash128 = Insecure.MD5.hash(data: Data(raw128.utf8)).map { String(format: "%02x", $0) }.joined() + ".thumb"
            keys.append(hash128)

            // 3. Requested display size key if different
            let intSize = Int(size)
            if intSize != 128 {
                let rawSize = "\(p)_\(modTime)_\(intSize)"
                let hashSize = Insecure.MD5.hash(data: Data(rawSize.utf8)).map { String(format: "%02x", $0) }.joined() + ".thumb"
                keys.append(hashSize)
            }
        }
        return keys
    }

    /// Whether a generated preview file exists in Contents/PREVIEWS or in memory
    public func hasGeneratedPreview(for item: FileItem, size: CGFloat = 128) -> Bool {
        let keys = candidateDiskKeys(for: item, size: size)
        for key in keys {
            if memoryCache.object(forKey: key as NSString) != nil {
                return true
            }
            let diskURL = cacheDirectoryURL.appendingPathComponent(key)
            if fileManager.fileExists(atPath: diskURL.path) {
                return true
            }
        }
        return false
    }

    /// Retrieve cached thumbnail immediately if a preview file exists in memory or Contents/PREVIEWS
    public func cachedThumbnail(for item: FileItem, size: CGFloat = 128) -> NSImage? {
        let keys = candidateDiskKeys(for: item, size: size)
        // 1. Check memory cache first
        for key in keys {
            if let memoryImg = memoryCache.object(forKey: key as NSString) {
                return memoryImg
            }
        }
        // 2. Check disk in Contents/PREVIEWS
        for key in keys {
            let diskURL = cacheDirectoryURL.appendingPathComponent(key)
            if let data = try? Data(contentsOf: diskURL), let diskImg = NSImage(data: data) {
                memoryCache.setObject(diskImg, forKey: key as NSString)
                return diskImg
            }
        }
        return nil
    }

    /// Prioritized thumbnail loader:
    /// 1. Prioritizes loading thumbnails for files for which previews have been generated in Contents/PREVIEWS.
    /// 2. If not pre-cached on disk yet, generates in-memory QuickLook thumbnail on-demand for visible items.
    /// 3. Falls back to standard system icon.
    public func loadThumbnail(
        for item: FileItem,
        targetSize: CGFloat = 128,
        completion: @escaping @Sendable (NSImage) -> Void
    ) {
        // 1. Check disk / memory cache with highest priority
        if let cached = cachedThumbnail(for: item, size: targetSize) {
            completion(cached)
            return
        }

        // 2. If eligible, generate high-quality thumbnail asynchronously
        guard isPreviewEligible(item: item) else {
            let fallback = IconCache.shared.icon(for: item.url.path)
            completion(fallback)
            return
        }

        let renderSize = max(targetSize * 2.0, 128.0)
        let request = QLThumbnailGenerator.Request(
            fileAt: item.url,
            size: CGSize(width: renderSize, height: renderSize),
            scale: 2.0,
            representationTypes: .thumbnail
        )

        let keys = candidateDiskKeys(for: item, size: targetSize)
        QLThumbnailGenerator.shared.generateBestRepresentation(for: request) { [weak self] rep, _ in
            guard let self = self else { return }
            if let rep = rep {
                let img = rep.nsImage
                for key in keys {
                    self.memoryCache.setObject(img, forKey: key as NSString)
                }
                completion(img)
            } else {
                let fallback = IconCache.shared.icon(for: item.url.path)
                completion(fallback)
            }
        }
    }

    private func saveThumbnailToDisk(image: NSImage, fileURL: URL) {
        guard let tiffData = image.tiffRepresentation,
              let rep = NSBitmapImageRep(data: tiffData),
              let jpegData = rep.representation(using: .jpeg, properties: [.compressionFactor: 0.85]) else {
            return
        }
        try? jpegData.write(to: fileURL, options: .atomic)
    }

    private func diskKey(for item: FileItem, size: CGFloat = 128) -> String {
        let modTime = item.dateModified?.timeIntervalSince1970 ?? 0
        let raw = "\(item.url.path)_\(modTime)_\(Int(size))"
        let hash = Insecure.MD5.hash(data: Data(raw.utf8))
        return hash.map { String(format: "%02x", $0) }.joined() + ".thumb"
    }

    /// Preload and cache preview thumbnails for a list of file items on disk
    public func preloadPreviews(for items: [FileItem], targetSize: CGFloat = 128) {
        let eligible = items.filter { isPreviewEligible(item: $0) }
        guard !eligible.isEmpty else { return }

        Task.detached(priority: .utility) { [weak self] in
            guard let self = self else { return }
            for item in eligible {
                let keys = self.candidateDiskKeys(for: item, size: targetSize)
                let primaryURL = self.cacheDirectoryURL.appendingPathComponent(keys[0])
                if self.fileManager.fileExists(atPath: primaryURL.path) {
                    continue
                }
                let request = QLThumbnailGenerator.Request(
                    fileAt: item.url,
                    size: CGSize(width: max(targetSize * 2.0, 128.0), height: max(targetSize * 2.0, 128.0)),
                    scale: 2.0,
                    representationTypes: .thumbnail
                )
                if let thumbnail = try? await QLThumbnailGenerator.shared.generateBestRepresentation(for: request) {
                    let image = thumbnail.nsImage
                    for key in keys {
                        self.memoryCache.setObject(image, forKey: key as NSString)
                        let diskURL = self.cacheDirectoryURL.appendingPathComponent(key)
                        self.saveThumbnailToDisk(image: image, fileURL: diskURL)
                    }
                }
            }
            Task { @MainActor in
                NotificationCenter.default.post(name: .previewThumbnailsDidUpdate, object: nil)
            }
        }
    }

    /// Preloads preview thumbnails for all files in a folder and saves to Contents/PREVIEWS
    public func preloadPreviewsForFolder(at folderURL: URL, recursive: Bool = true, onProgress: (@Sendable (Int, Int) -> Void)? = nil) {
        Task.detached(priority: .userInitiated) { [weak self] in
            guard let self = self else { return }
            let keys: [URLResourceKey] = [.isDirectoryKey, .isPackageKey]
            var options: FileManager.DirectoryEnumerationOptions = [.skipsHiddenFiles]
            if !recursive {
                options.insert(.skipsSubdirectoryDescendants)
            }

            guard let enumerator = self.fileManager.enumerator(
                at: folderURL,
                includingPropertiesForKeys: keys,
                options: options
            ) else { return }

            var fileURLs: [URL] = []
            while let url = enumerator.nextObject() as? URL {
                if let vals = try? url.resourceValues(forKeys: Set(keys)) {
                    if vals.isDirectory != true {
                        let ext = url.pathExtension.lowercased()
                        if self.previewExtensions.contains(ext) {
                            fileURLs.append(url)
                        }
                    }
                }
            }

            let total = fileURLs.count
            var completed = 0

            for url in fileURLs {
                let item = FileItem(url: url)
                let candidateKeys = self.candidateDiskKeys(for: item, size: 128)
                let primaryURL = self.cacheDirectoryURL.appendingPathComponent(candidateKeys[0])

                if !self.fileManager.fileExists(atPath: primaryURL.path) {
                    let request = QLThumbnailGenerator.Request(
                        fileAt: url,
                        size: CGSize(width: 256, height: 256),
                        scale: 2.0,
                        representationTypes: .thumbnail
                    )
                    if let thumb = try? await QLThumbnailGenerator.shared.generateBestRepresentation(for: request) {
                        let img = thumb.nsImage
                        for k in candidateKeys {
                            self.memoryCache.setObject(img, forKey: k as NSString)
                            let diskURL = self.cacheDirectoryURL.appendingPathComponent(k)
                            self.saveThumbnailToDisk(image: img, fileURL: diskURL)
                        }
                    }
                }
                completed += 1
                onProgress?(completed, total)

                // Periodically update the UI as previews finish generating
                if completed % 5 == 0 || completed == total {
                    Task { @MainActor in
                        NotificationCenter.default.post(name: .previewThumbnailsDidUpdate, object: nil)
                    }
                }
            }

            Task { @MainActor in
                NotificationCenter.default.post(name: .previewThumbnailsDidUpdate, object: nil)
            }
        }
    }

    // MARK: - Cache Cleanup (Delete preview files older than 14 days)

    /// Deletes all cached preview files older than `maxAgeInDays` (default 14 days)
    public func cleanOldPreviews(maxAgeInDays: Int = 14) {
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
