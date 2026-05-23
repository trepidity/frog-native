import Foundation

struct ScoredResult: Comparable {
    let item: FileItem
    let score: Double
    static func < (lhs: ScoredResult, rhs: ScoredResult) -> Bool {
        lhs.score > rhs.score
    }
}

extension PaneState {
    func searchFiles(query: String) async -> [FileItem] {
        guard !query.isEmpty else { return [] }
        let rootURL = currentDirectory
        let now = Date()

        return await Task.detached(priority: .userInitiated) {
            Self.runSearch(query: query, rootURL: rootURL, now: now)
        }.value
    }

    nonisolated private static func runSearch(
        query: String,
        rootURL: URL,
        now: Date
    ) -> [FileItem] {
        let manager = FileManager.default
        let keys: [URLResourceKey] = [
            .isDirectoryKey,
            .fileSizeKey,
            .contentModificationDateKey,
            .creationDateKey
        ]
        let options: FileManager.DirectoryEnumerationOptions = [
            .skipsHiddenFiles,
            .skipsPackageDescendants
        ]
        guard let enumerator = manager.enumerator(
            at: rootURL,
            includingPropertiesForKeys: keys,
            options: options
        ) else {
            return []
        }

        var scoredResults: [ScoredResult] = []
        while let url = enumerator.nextObject() as? URL {
            let name = url.lastPathComponent
            guard name.localizedCaseInsensitiveContains(query) else { continue }
            let item = FileItem(url: url)
            let nameScore = scoreName(name, against: query)
            let recencyScore = scoreRecency(item.modificationDate, now: now)
            scoredResults.append(ScoredResult(item: item, score: nameScore + recencyScore))
            if scoredResults.count >= 100 { break }
            if Task.isCancelled { return [] }
        }
        return scoredResults.sorted().prefix(20).map { $0.item }
    }

    nonisolated private static func scoreName(_ name: String, against query: String) -> Double {
        if name.localizedCaseInsensitiveCompare(query) == .orderedSame {
            return 1.0
        }
        if name.lowercased().hasPrefix(query.lowercased()) {
            return 0.8
        }
        return 0.5
    }

    nonisolated private static func scoreRecency(_ modificationDate: Date, now: Date) -> Double {
        let interval = now.timeIntervalSince(modificationDate)
        if interval < 3600 { return 1.0 }
        if interval < 86400 { return 0.5 }
        if interval < 604800 { return 0.2 }
        return 0.0
    }
}
