import Foundation

extension PaneState {
    static func renameNameError(_ name: String) -> String? {
        if name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return "Enter a name."
        }
        if name == "." || name == ".." || name.contains("/") || name.contains("\0") {
            return "Use a filename, without a slash. “.” and “..” are reserved names."
        }
        return nil
    }

    func rename(_ item: FileItem, to newName: String) throws {
        if let message = Self.renameNameError(newName) {
            throw CocoaError(.fileWriteInvalidFileName, userInfo: [NSLocalizedDescriptionKey: message])
        }
        guard newName != item.name else { return }
        let destination = item.url.deletingLastPathComponent()
            .appendingPathComponent(newName, isDirectory: item.isDirectory)
        // FileManager refuses an existing destination rather than replacing it.
        try FileManager.default.moveItem(at: item.url, to: destination)

        func relocated(_ url: URL) -> URL {
            if url.path == item.url.path { return destination }
            let prefix = item.url.path + "/"
            guard url.path.hasPrefix(prefix) else { return url }
            return destination.appendingPathComponent(String(url.path.dropFirst(prefix.count)), isDirectory: url.hasDirectoryPath)
        }
        func updated(_ entry: FileItem) -> FileItem {
            let url = relocated(entry.url)
            return url == entry.url ? entry : FileItem(url: url)
        }

        // Update visible rows before selecting the new URL, including expanded children.
        items = Self.sortItems(items.map(updated), field: sortField, order: sortOrder)
        itemChildren = Dictionary(uniqueKeysWithValues: itemChildren.map { url, children in
            (relocated(url), Self.sortItems(children.map(updated), field: sortField, order: sortOrder))
        })
        expandedItems = Set(expandedItems.map(relocated))
        cachedVisibleItems = nil
        selection = [destination]
        NotificationCenter.default.post(name: Self.shouldRefreshPanes, object: nil)
    }
}
