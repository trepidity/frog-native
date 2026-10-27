import Foundation
import Testing
@testable import frog_native

struct HiddenVisibilityTests {
    @Test @MainActor func hidingItemsFiltersEveryTreeLevelAndPreservesExpansion() async throws {
        let root = FileManager.default.temporaryDirectory.canonicalDirectoryURL.appendingPathComponent("frog-visibility-\(UUID())")
        defer { try? FileManager.default.removeItem(at: root) }
        let folder = root.appendingPathComponent("visible"), hidden = root.appendingPathComponent(".secret")
        for directory in [folder, hidden] { try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true) }
        for path in ["notes.txt", ".env", "flag-hidden.txt", "visible/child.txt", "visible/.nested", ".secret/inside.txt"] {
            try Data().write(to: root.appendingPathComponent(path))
        }
        var flagged = root.appendingPathComponent("flag-hidden.txt")
        var values = URLResourceValues()
        values.isHidden = true
        try flagged.setResourceValues(values)
        let pane = PaneState(id: "visibility-\(UUID())", directory: root)
        pane.loadTask?.cancel()
        pane.cancellables.removeAll()
        await pane.loadTask?.value
        defer { pane.expandedItems = [] }
        pane.items = [folder, hidden, root.appendingPathComponent("notes.txt"), root.appendingPathComponent(".env"), flagged].map { FileItem(url: $0) }
        pane.itemChildren = [folder: [".nested", "child.txt"].map { FileItem(url: folder.appendingPathComponent($0)) },
                             hidden: [FileItem(url: hidden.appendingPathComponent("inside.txt"))]]
        pane.expandedItems = [folder, hidden]
        pane.setHiddenFilesVisible(true)
        #expect(pane.visibleItems.count == 8)
        pane.selection = [root.appendingPathComponent(".env")]
        pane.setHiddenFilesVisible(false)
        #expect(pane.displayedItems.map(\.name) == ["visible", "notes.txt"])
        #expect(pane.visibleItems.map(\.item.name) == ["visible", "child.txt", "notes.txt"])
        #expect(pane.selection.isEmpty)
        pane.selection = [folder]
        pane.handleRightArrow()
        #expect(pane.selection == [folder.appendingPathComponent("child.txt")])
        pane.setHiddenFilesVisible(true)
        #expect(pane.visibleItems.count == 8)
        #expect(pane.expandedItems == Set([folder, hidden]))
    }
}
