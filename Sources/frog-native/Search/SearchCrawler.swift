import Foundation
import Darwin

struct SearchCrawlReport: Sendable {
    let count: Int
    let denied: Int
}

enum SearchCrawler {
    /// Name/type metadata only. Hidden files and package descendants are deliberately included.
    static func scan(root: URL, excluding exclusions: Set<String>, into index: FilenameIndex,
                     progress: @Sendable (Int) async -> Void = { _ in }) async throws -> SearchCrawlReport {
        // Preserve the final component: file-event paths may themselves be symlinks.
        let root = root.path == "/" ? root : root.deletingLastPathComponent().canonicalDirectoryURL.appendingPathComponent(root.lastPathComponent)
        let generation = UUID().uuidString
        let keys: [URLResourceKey] = [.isDirectoryKey, .isSymbolicLinkKey, .volumeIsLocalKey]
        let failures = CrawlFailures()
        var attributes = stat()
        guard lstat(root.path, &attributes) == 0 else {
            // EACCES is not deletion. Only a definite missing path invalidates rows.
            guard errno == ENOENT || errno == ENOTDIR else { return SearchCrawlReport(count: 0, denied: 1) }
            try await index.prune(root: root, generation: generation)
            return SearchCrawlReport(count: 0, denied: 0)
        }
        let isDirectory = attributes.st_mode & S_IFMT == S_IFDIR
        var batch = [SearchEntry(url: root, isDirectory: isDirectory)]
        var count = 1
        if isDirectory {
            // Publish immediate children first, so a huge first branch cannot hide a
            // sibling such as ~/.config until the entire depth-first crawl finishes.
            if let children = try? FileManager.default.contentsOfDirectory(at: root, includingPropertiesForKeys: keys) {
                let immediate = children.filter { !exclusions.contains($0.path) }.map {
                    SearchEntry(url: $0, isDirectory: (try? $0.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) == true)
                }
                for offset in stride(from: 0, to: immediate.count, by: 256) {
                    try Task.checkCancellation()
                    try await index.upsert(Array(immediate[offset..<min(offset + 256, immediate.count)]), generation: generation)
                }
                await progress(immediate.count)
            }
            guard let enumerator = FileManager.default.enumerator(at: root, includingPropertiesForKeys: keys, options: [],
                errorHandler: { url, _ in failures.paths.append(url); return true }) else {
                return SearchCrawlReport(count: 0, denied: 1)
            }
            while let url = enumerator.nextObject() as? URL {
                try Task.checkCancellation()
                if exclusions.contains(url.path) { enumerator.skipDescendants(); continue }
                let values = try? url.resourceValues(forKeys: Set(keys))
                if values?.isSymbolicLink == true { enumerator.skipDescendants() }
                if values?.isDirectory == true && values?.volumeIsLocal == false {
                    enumerator.skipDescendants()
                    continue
                }
                batch.append(SearchEntry(url: url, isDirectory: values?.isDirectory == true))
                count += 1
                if batch.count >= 256 {
                    try await index.upsert(batch, generation: generation)
                    batch.removeAll(keepingCapacity: true)
                    if count % 4096 == 0 { await progress(count) }
                    await Task.yield()
                }
            }
        }
        try await index.upsert(batch, generation: generation)
        // Preserve inaccessible subtrees instead of mistaking denied access for deletion.
        for denied in failures.paths { try await index.preserve(root: denied, generation: generation) }
        // An explicit exclusion can be an independently scanned root (home is prioritized).
        for excluded in exclusions { try await index.preserve(root: URL(fileURLWithPath: excluded), generation: generation) }
        try Task.checkCancellation()
        try await index.prune(root: root, generation: generation)
        await progress(count)
        return SearchCrawlReport(count: count, denied: failures.paths.count)
    }
}

// The enumerator invokes its error handler synchronously on the crawling task.
private final class CrawlFailures { var paths: [URL] = [] }
