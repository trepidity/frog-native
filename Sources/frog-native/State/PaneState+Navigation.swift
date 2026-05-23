import Foundation
import AppKit

extension PaneState {
    func enterSoloMode() {
        guard let selectedID = selection.first,
              let treeItem = visibleItems.first(where: { $0.id == selectedID }),
              treeItem.item.isDirectory else { return }
        soloRoot = treeItem.item.url
        loadContents()
        selection = []
    }

    func exitSoloMode() {
        soloRoot = nil
        loadContents()
        selection = []
    }

    func selectNext() {
        let visible = visibleItems
        guard !visible.isEmpty else { return }
        if let selectedID = selection.first,
           let currentIndex = visible.firstIndex(where: { $0.id == selectedID }) {
            let nextIndex = min(currentIndex + 1, visible.count - 1)
            selection = [visible[nextIndex].id]
        } else {
            selection = [visible[0].id]
        }
    }

    func selectPrevious() {
        let visible = visibleItems
        guard !visible.isEmpty else { return }
        if let selectedID = selection.first,
           let currentIndex = visible.firstIndex(where: { $0.id == selectedID }) {
            let prevIndex = max(currentIndex - 1, 0)
            selection = [visible[prevIndex].id]
        } else {
            selection = [visible[0].id]
        }
    }

    func handleRightArrow() {
        guard let selectedID = selection.first,
              let treeItem = visibleItems.first(where: { $0.id == selectedID }) else { return }
        let item = treeItem.item
        guard item.isDirectory else { return }
        if !expandedItems.contains(item.url) {
            toggleExpansion(for: item)
        } else if let children = itemChildren[item.url], !children.isEmpty {
            selection = [children[0].url]
        }
    }

    func handleLeftArrow() {
        guard let selectedID = selection.first else { return }
        let visible = visibleItems
        guard let currentIndex = visible.firstIndex(where: { $0.id == selectedID }) else { return }
        let treeItem = visible[currentIndex]
        let item = treeItem.item

        if item.isDirectory && expandedItems.contains(item.url) {
            toggleExpansion(for: item)
            return
        }
        for idx in (0..<currentIndex).reversed() {
            let potentialParent = visible[idx]
            if let children = itemChildren[potentialParent.id],
               children.contains(where: { $0.url == selectedID }) {
                selection = [potentialParent.id]
                return
            }
        }
        navigateOut()
    }

    func handleSpacebar() {
        guard let selectedID = selection.first,
              let treeItem = visibleItems.first(where: { $0.id == selectedID }),
              !treeItem.item.isDirectory else {
            previewURL = nil
            return
        }
        let item = treeItem.item
        previewURL = (previewURL == item.url) ? nil : item.url
    }

    func activate(_ item: FileItem) {
        selection = [item.url]
        if item.isDirectory {
            toggleExpansion(for: item)
        } else {
            smartOpen(item.url)
        }
    }

    func smartOpen(_ url: URL) {
        let textExtensions: Set<String> = [
            "txt", "md", "json", "swift", "js", "ts",
            "html", "css", "py", "sh", "yml", "yaml"
        ]
        if textExtensions.contains(url.pathExtension.lowercased()) {
            mode = .editor(url)
        } else {
            NSWorkspace.shared.open(url)
        }
    }

    func openWith(_ url: URL, appURL: URL? = nil) {
        if let appURL = appURL {
            NSWorkspace.shared.open(
                [url],
                withApplicationAt: appURL,
                configuration: NSWorkspace.OpenConfiguration()
            )
        } else {
            NSWorkspace.shared.open(url)
        }
    }

    func updateDirectory(_ newURL: URL, clearForward: Bool = true) {
        guard newURL != currentDirectory else { return }
        if clearForward {
            backStack.append(currentDirectory)
            forwardStack.removeAll()
        }
        currentDirectory = newURL
        selection = []
    }

    func navigateIn() {
        guard let selectedID = selection.first,
              let treeItem = visibleItems.first(where: { $0.id == selectedID }) else { return }
        let item = treeItem.item
        if item.isDirectory {
            updateDirectory(item.url)
        } else {
            smartOpen(item.url)
        }
    }

    func closeEditor() {
        mode = .browser
    }

    func navigateOut() {
        let parent = currentDirectory.deletingLastPathComponent()
        guard parent.path != currentDirectory.path else { return }
        updateDirectory(parent)
    }

    func navigateBack() {
        guard let previous = backStack.popLast() else { return }
        forwardStack.append(currentDirectory)
        updateDirectory(previous, clearForward: false)
    }

    func navigateForward() {
        guard let next = forwardStack.popLast() else { return }
        backStack.append(currentDirectory)
        updateDirectory(next, clearForward: false)
    }
}
