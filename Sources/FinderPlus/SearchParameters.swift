import Foundation

public enum SearchScope: String, CaseIterable, Identifiable, Sendable {
    case currentFolderOnly = "This Folder"
    case currentFolderAndSubfolders = "Subfolders"
    case entireMac = "This Mac"

    public var id: String { rawValue }

    public var description: String {
        switch self {
        case .currentFolderOnly:
            return "Search only inside the selected folder (non-recursive)"
        case .currentFolderAndSubfolders:
            return "Search selected folder and all subdirectories"
        case .entireMac:
            return "Search entire user system / Macintosh HD"
        }
    }
}

public enum MatchMode: String, CaseIterable, Identifiable, Sendable {
    case contains = "Contains"
    case exact = "Exact"
    case regex = "Regex"

    public var id: String { rawValue }
}

public enum SearchTarget: String, CaseIterable, Identifiable, Sendable {
    case fileName = "Name"
    case fileContent = "Content"

    public var id: String { rawValue }
}

public enum KindFilter: String, CaseIterable, Identifiable, Sendable {
    case any = "All Kinds"
    case folders = "Folders"
    case documents = "Documents"
    case images = "Images"
    case audio = "Audio"
    case video = "Movies"
    case code = "Code"
    case archives = "Archives"

    public var id: String { rawValue }

    public func matches(item: FileItem) -> Bool {
        switch self {
        case .any:
            return true
        case .folders:
            return item.isDirectory
        case .documents:
            let docExts: Set<String> = ["pdf", "doc", "docx", "txt", "rtf", "pages", "numbers", "key", "xls", "xlsx", "ppt", "pptx", "csv", "md"]
            return docExts.contains(item.fileExtension)
        case .images:
            let imgExts: Set<String> = ["png", "jpg", "jpeg", "heic", "gif", "tiff", "svg", "webp", "bmp", "ico", "psd"]
            return imgExts.contains(item.fileExtension)
        case .audio:
            let audioExts: Set<String> = ["mp3", "m4a", "wav", "aac", "flac", "aiff", "ogg"]
            return audioExts.contains(item.fileExtension)
        case .video:
            let videoExts: Set<String> = ["mp4", "mov", "m4v", "mkv", "avi", "webm"]
            return videoExts.contains(item.fileExtension)
        case .code:
            let codeExts: Set<String> = ["swift", "m", "h", "c", "cpp", "py", "js", "ts", "jsx", "tsx", "html", "css", "json", "yaml", "yml", "xml", "sh", "rs", "go", "java", "kt", "rb", "php", "sql"]
            return codeExts.contains(item.fileExtension)
        case .archives:
            let archiveExts: Set<String> = ["zip", "tar", "gz", "tgz", "rar", "7z", "dmg", "pkg"]
            return archiveExts.contains(item.fileExtension)
        }
    }
}

public enum DateFilter: String, CaseIterable, Identifiable, Sendable {
    case any = "Any Date"
    case today = "Today"
    case pastWeek = "Past 7 Days"
    case pastMonth = "Past 30 Days"
    case pastYear = "Past Year"

    public var id: String { rawValue }

    public func matches(date: Date?) -> Bool {
        guard self != .any else { return true }
        guard let date = date else { return false }
        let now = Date()
        let calendar = Calendar.current

        switch self {
        case .any:
            return true
        case .today:
            return calendar.isDateInToday(date)
        case .pastWeek:
            guard let cutoff = calendar.date(byAdding: .day, value: -7, to: now) else { return false }
            return date >= cutoff
        case .pastMonth:
            guard let cutoff = calendar.date(byAdding: .day, value: -30, to: now) else { return false }
            return date >= cutoff
        case .pastYear:
            guard let cutoff = calendar.date(byAdding: .year, value: -1, to: now) else { return false }
            return date >= cutoff
        }
    }
}

public enum SizeFilter: String, CaseIterable, Identifiable, Sendable {
    case any = "Any Size"
    case small = "< 1 MB"
    case medium = "1 MB - 100 MB"
    case large = "> 100 MB"

    public var id: String { rawValue }

    public func matches(size: Int64, isDirectory: Bool) -> Bool {
        if isDirectory { return true }
        switch self {
        case .any:
            return true
        case .small:
            return size < 1_000_000
        case .medium:
            return size >= 1_000_000 && size <= 100_000_000
        case .large:
            return size > 100_000_000
        }
    }
}

public struct SearchParameters: Equatable, Sendable {
    public var scope: SearchScope = .currentFolderOnly
    public var matchMode: MatchMode = .contains
    public var searchTarget: SearchTarget = .fileName
    public var isCaseSensitive: Bool = false
    public var kindFilter: KindFilter = .any
    public var dateFilter: DateFilter = .any
    public var sizeFilter: SizeFilter = .any
    public var includeHiddenFiles: Bool = false

    public init() {}
}
