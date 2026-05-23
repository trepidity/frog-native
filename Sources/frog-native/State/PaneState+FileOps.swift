import Foundation
import AppKit

extension PaneState {
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

    func moveSelectionToTrash() {
        let selectedItems = visibleItems.filter { selection.contains($0.id) }.map { $0.item }
        guard !selectedItems.isEmpty else { return }
        let urls = selectedItems.map { $0.url }
        NSWorkspace.shared.recycle(urls) { _, error in
            DispatchQueue.main.async {
                if let error = error {
                    SoundManager.shared.play(.error)
                    print("Error moving to trash: \(error)")
                } else {
                    SoundManager.shared.play(.teleport)
                }
                NotificationCenter.default.post(name: Self.shouldRefreshPanes, object: nil)
                self.selection = []
            }
        }
    }

    func copySelectionToClipboardRich() {
        let selectedItems = visibleItems.filter { selection.contains($0.id) }.map { $0.item }
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
