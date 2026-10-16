import Foundation

public actor SearchEngine {
    public struct SearchProgress: Sendable {
        public let scannedCount: Int
        public let matchesCount: Int
        public let isFinished: Bool
    }

    public init() {}

    public func search(
        query: String,
        baseDirectory: URL,
        parameters: SearchParameters,
        onProgress: (@Sendable (SearchProgress) -> Void)? = nil
    ) -> AsyncStream<FileItem> {
        AsyncStream { continuation in
            let task = Task.detached(priority: .userInitiated) {
                var scanned = 0
                var matches = 0

                let roots: [URL]
                switch parameters.scope {
                case .currentFolderOnly, .currentFolderAndSubfolders:
                    roots = [baseDirectory]
                case .entireMac:
                    let home = FileManager.default.homeDirectoryForCurrentUser
                    roots = [home, URL(fileURLWithPath: "/Applications")]
                }

                var regex: NSRegularExpression?
                if parameters.matchMode == .regex && !query.isEmpty {
                    var options: NSRegularExpression.Options = []
                    if !parameters.isCaseSensitive {
                        options.insert(.caseInsensitive)
                    }
                    regex = try? NSRegularExpression(pattern: query, options: options)
                }

                let isRecursive = parameters.scope != .currentFolderOnly

                for root in roots {
                    if Task.isCancelled { break }

                    if !isRecursive {
                        // Scan only direct children
                        let resourceKeys: Set<URLResourceKey> = [
                            .isDirectoryKey,
                            .isPackageKey,
                            .isHiddenKey,
                            .fileSizeKey,
                            .contentModificationDateKey,
                            .contentTypeKey,
                            .localizedTypeDescriptionKey
                        ]

                        var options: FileManager.DirectoryEnumerationOptions = []
                        if !parameters.includeHiddenFiles {
                            options.insert(.skipsHiddenFiles)
                        }

                        let children = (try? FileManager.default.contentsOfDirectory(
                            at: root,
                            includingPropertiesForKeys: Array(resourceKeys),
                            options: options
                        )) ?? []

                        for url in children {
                            if Task.isCancelled { break }
                            scanned += 1

                            if let item = self.evaluate(
                                url: url,
                                query: query,
                                regex: regex,
                                parameters: parameters
                            ) {
                                matches += 1
                                continuation.yield(item)
                            }

                            if scanned % 50 == 0 {
                                onProgress?(SearchProgress(scannedCount: scanned, matchesCount: matches, isFinished: false))
                            }
                        }
                    } else {
                        // Deep recursive scan
                        let resourceKeys: [URLResourceKey] = [
                            .isDirectoryKey,
                            .isPackageKey,
                            .isHiddenKey,
                            .fileSizeKey,
                            .contentModificationDateKey,
                            .contentTypeKey,
                            .localizedTypeDescriptionKey
                        ]

                        var options: FileManager.DirectoryEnumerationOptions = []
                        if !parameters.includeHiddenFiles {
                            options.insert(.skipsHiddenFiles)
                        }

                        guard let enumerator = FileManager.default.enumerator(
                            at: root,
                            includingPropertiesForKeys: resourceKeys,
                            options: options,
                            errorHandler: { _, _ in true }
                        ) else { continue }

                        while let url = enumerator.nextObject() as? URL {
                            if Task.isCancelled { break }
                            scanned += 1

                            // Skip deep recursion inside packages (e.g. .app bundles) unless requested
                            if let vals = try? url.resourceValues(forKeys: [.isPackageKey]), vals.isPackage == true {
                                enumerator.skipDescendants()
                            }

                            if let item = self.evaluate(
                                url: url,
                                query: query,
                                regex: regex,
                                parameters: parameters
                            ) {
                                matches += 1
                                continuation.yield(item)
                            }

                            if scanned % 100 == 0 {
                                onProgress?(SearchProgress(scannedCount: scanned, matchesCount: matches, isFinished: false))
                            }
                        }
                    }
                }

                onProgress?(SearchProgress(scannedCount: scanned, matchesCount: matches, isFinished: true))
                continuation.finish()
            }

            continuation.onTermination = { @Sendable _ in
                task.cancel()
            }
        }
    }

    private nonisolated func evaluate(
        url: URL,
        query: String,
        regex: NSRegularExpression?,
        parameters: SearchParameters
    ) -> FileItem? {
        let name = url.lastPathComponent
        if !parameters.includeHiddenFiles && (name.hasPrefix(".") || url.pathComponents.contains { $0.hasPrefix(".") }) {
            return nil
        }

        let item = FileItem(url: url)

        // Filter checks
        if !parameters.kindFilter.matches(item: item) {
            return nil
        }

        if !parameters.dateFilter.matches(date: item.dateModified) {
            return nil
        }

        if !parameters.sizeFilter.matches(size: item.size, isDirectory: item.isDirectory) {
            return nil
        }

        // If query is empty, it matches (all items passing the filters)
        if query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return item
        }

        // Check Target
        switch parameters.searchTarget {
        case .fileName:
            if matchesText(target: item.name, query: query, regex: regex, parameters: parameters) {
                return item
            }
        case .fileContent:
            // Content search only applies to regular files under 10MB
            guard !item.isDirectory && !item.isPackage && item.size > 0 && item.size < 10_000_000 else {
                return nil
            }
            if matchesContent(url: url, query: query, regex: regex, parameters: parameters) {
                return item
            }
        }

        return nil
    }

    private nonisolated func matchesText(
        target: String,
        query: String,
        regex: NSRegularExpression?,
        parameters: SearchParameters
    ) -> Bool {
        switch parameters.matchMode {
        case .contains:
            if parameters.isCaseSensitive {
                return target.contains(query)
            } else {
                return target.localizedStandardContains(query)
            }
        case .exact:
            if parameters.isCaseSensitive {
                return target == query
            } else {
                return target.caseInsensitiveCompare(query) == .orderedSame
            }
        case .regex:
            guard let regex = regex else { return false }
            let range = NSRange(target.startIndex..<target.endIndex, in: target)
            return regex.firstMatch(in: target, options: [], range: range) != nil
        }
    }

    private nonisolated func matchesContent(
        url: URL,
        query: String,
        regex: NSRegularExpression?,
        parameters: SearchParameters
    ) -> Bool {
        guard let data = try? Data(contentsOf: url, options: .mappedIfSafe) else {
            return false
        }

        // Quick binary check: scan first 512 bytes for null bytes
        let prefixLimit = min(data.count, 512)
        if prefixLimit > 0 {
            var nullFound = false
            data.withUnsafeBytes { ptr in
                guard let base = ptr.bindMemory(to: UInt8.self).baseAddress else { return }
                for i in 0..<prefixLimit {
                    if base[i] == 0 {
                        nullFound = true
                        break
                    }
                }
            }
            if nullFound { return false }
        }

        guard let text = String(data: data, encoding: .utf8) ?? String(data: data, encoding: .ascii) else {
            return false
        }

        return matchesText(target: text, query: query, regex: regex, parameters: parameters)
    }
}
