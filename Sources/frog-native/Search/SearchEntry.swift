import Foundation
import Darwin

extension URL {
    /// Foundation may abbreviate /private/var to /var, while directory enumeration
    /// returns /private/var. Use the filesystem spelling for navigation/index identity.
    var canonicalDirectoryURL: URL {
        var ancestor = standardizedFileURL
        var suffix: [String] = []
        while true {
            if let resolved = realpath(ancestor.path, nil) {
                defer { free(resolved) }
                var result = URL(fileURLWithPath: String(cString: resolved), isDirectory: true)
                for component in suffix.reversed() { result.appendPathComponent(component) }
                return result
            }
            guard ancestor.path != "/" else { return standardizedFileURL }
            suffix.append(ancestor.lastPathComponent)
            ancestor.deleteLastPathComponent()
        }
    }
}

/// Search never constructs FileItem (which reads image headers and rich metadata).
struct SearchEntry: Identifiable, Hashable, Sendable {
    let url: URL
    let isDirectory: Bool
    var id: String { url.path }
    var name: String { url.lastPathComponent.isEmpty ? "/" : url.lastPathComponent }

    static func normalize(_ text: String) -> String {
        text.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: Locale(identifier: "en_US_POSIX"))
    }

    static func ranked(_ entries: [SearchEntry], query: String, limit: Int = 40) -> [SearchEntry] {
        let needle = normalize(query)
        func rank(_ entry: SearchEntry) -> Int {
            let name = normalize(entry.name)
            if name == needle || name == "." + needle { return 0 }
            if name.hasPrefix(needle) || name.hasPrefix("." + needle) { return 1 }
            return 2
        }
        let sorted = Array(Set(entries)).sorted {
            let left = rank($0), right = rank($1)
            if left != right { return left < right }
            if $0.isDirectory != $1.isDirectory { return $0.isDirectory }
            if $0.url.path.count != $1.url.path.count { return $0.url.path.count < $1.url.path.count }
            return $0.url.path < $1.url.path
        }
        return Array(sorted.prefix(limit))
    }

    static func directPathMatches(_ text: String) throws -> [SearchEntry] {
        try Task.checkCancellation()
        guard text.hasPrefix("/") || text.hasPrefix("~") else { return [] }
        let path = (text as NSString).expandingTildeInPath
        let url = URL(fileURLWithPath: path).standardizedFileURL
        var directory: ObjCBool = false
        var results: [SearchEntry] = []
        if FileManager.default.fileExists(atPath: url.path, isDirectory: &directory) {
            results.append(SearchEntry(url: url, isDirectory: directory.boolValue))
        }
        let parent = text.hasSuffix("/") ? url : url.deletingLastPathComponent()
        let prefix = text.hasSuffix("/") ? "" : normalize(url.lastPathComponent)
        var readError: Error?
        let children = FileManager.default.enumerator(
            at: parent,
            includingPropertiesForKeys: [.isDirectoryKey],
            options: [.skipsSubdirectoryDescendants],
            errorHandler: { _, error in readError = error; return false }
        )
        while let child = children?.nextObject() as? URL {
            try Task.checkCancellation()
            guard normalize(child.lastPathComponent).hasPrefix(prefix) else { continue }
            results.append(SearchEntry(url: child, isDirectory: (try? child.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) == true))
            if results.count >= 100 { break }
        }
        try Task.checkCancellation()
        if let readError, results.isEmpty { throw readError }
        return results
    }
}
