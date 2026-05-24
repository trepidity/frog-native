import Foundation
import AppKit

extension PaneState {
    private var selectedVisibleItems: [FileItem] {
        visibleItems.filter { selection.contains($0.id) }.map(\.item)
    }

    func createNewFolder() {
        let baseUrl = currentDirectory
        var folderName = "untitled folder"
        var folderUrl = baseUrl.appendingPathComponent(folderName)
        var count = 2
        while FileManager.default.fileExists(atPath: folderUrl.path) {
            folderName = "untitled folder \(count)"
            folderUrl = baseUrl.appendingPathComponent(folderName)
            count += 1
        }
        do {
            try FileManager.default.createDirectory(at: folderUrl, withIntermediateDirectories: true)
            loadContents()
            if let newItem = items.first(where: { $0.url.path == folderUrl.path }) {
                selection = [newItem.url]
            }
        } catch {
            print("Error creating folder: \(error)")
        }
    }

    func renameSelected(to newName: String) {
        guard let selectedID = selection.first,
              let treeItem = visibleItems.first(where: { $0.id == selectedID }) else { return }
        let item = treeItem.item
        let newURL = item.url.deletingLastPathComponent().appendingPathComponent(newName)
        do {
            try FileManager.default.moveItem(at: item.url, to: newURL)
            loadContents()
            if let newItem = items.first(where: { $0.url.path == newURL.path }) {
                selection = [newItem.url]
            }
        } catch {
            print("Error renaming item: \(error)")
        }
    }

    func moveItem(at sourceURL: URL, to destinationDirectory: URL) {
        let destinationURL = destinationDirectory.appendingPathComponent(sourceURL.lastPathComponent)
        guard sourceURL.path != destinationURL.path else { return }
        do {
            try FileManager.default.moveItem(at: sourceURL, to: destinationURL)
            SoundManager.shared.play(.teleport)
            NotificationCenter.default.post(name: Self.shouldRefreshPanes, object: nil)
        } catch {
            SoundManager.shared.play(.error)
            print("Error moving item: \(error)")
        }
    }

    func confirmMoveSelectionToTrash() {
        let selectedItems = selectedVisibleItems
        guard !selectedItems.isEmpty else { return }

        let alert = NSAlert()
        alert.alertStyle = .warning
        if selectedItems.count == 1 {
            alert.messageText = "Move “\(selectedItems[0].name)” to Trash?"
            alert.informativeText = "This will move the selected item to the system Trash."
        } else {
            alert.messageText = "Move \(selectedItems.count) items to Trash?"
            alert.informativeText = "This will move the selected items to the system Trash."
        }
        alert.addButton(withTitle: "Move to Trash")
        alert.addButton(withTitle: "Cancel")

        if alert.runModal() == .alertFirstButtonReturn {
            moveSelectionToTrash()
        }
    }

    func moveSelectionToTrash() {
        let selectedItems = selectedVisibleItems
        guard !selectedItems.isEmpty else { return }
        let urls = selectedItems.map { $0.url }
        let existingURLs = Self.existingURLsForTrash(in: urls)

        guard !existingURLs.isEmpty else {
            SoundManager.shared.play(.teleport)
            NotificationCenter.default.post(name: Self.shouldRefreshPanes, object: nil)
            self.selection = []
            return
        }

        NSWorkspace.shared.recycle(existingURLs) { _, error in
            DispatchQueue.main.async {
                if let error = error {
                    if Self.isMissingFileError(error) {
                        SoundManager.shared.play(.teleport)
                    } else {
                        SoundManager.shared.play(.error)
                        print("Error moving to trash: \(error)")
                    }
                } else {
                    SoundManager.shared.play(.teleport)
                }
                NotificationCenter.default.post(name: Self.shouldRefreshPanes, object: nil)
                self.selection = []
            }
        }
    }

    nonisolated static func existingURLsForTrash(in urls: [URL]) -> [URL] {
        urls.filter { FileManager.default.fileExists(atPath: $0.path) }
    }

    nonisolated static func isMissingFileError(_ error: Error) -> Bool {
        let nsError = error as NSError
        if (nsError.domain == NSCocoaErrorDomain && nsError.code == NSFileNoSuchFileError)
            || (nsError.domain == NSOSStatusErrorDomain && nsError.code == -43) {
            return true
        }

        if let underlying = nsError.userInfo[NSUnderlyingErrorKey] as? Error,
           isMissingFileError(underlying) {
            return true
        }

        if let underlyingErrors = nsError.userInfo["NSUnderlyingErrors"] as? [NSError] {
            return underlyingErrors.allSatisfy(isMissingFileError)
        }

        return false
    }

    func copySelectionToClipboardRich() {
        let selectedItems = selectedVisibleItems
        guard !selectedItems.isEmpty else { return }

        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()

        let urls = selectedItems.map { $0.url as NSURL }
        pasteboard.writeObjects(urls)

        for item in selectedItems where item.isImage {
            if let image = NSImage(contentsOf: item.url) {
                pasteboard.setData(image.tiffRepresentation, forType: .tiff)
            }
        }
        SoundManager.shared.play(.teleport)
    }
}
