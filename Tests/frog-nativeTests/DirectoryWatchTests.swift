import Foundation
import Testing
@testable import frog_native

struct DirectoryWatchTests {
    @Test @MainActor func openFolderReflectsExternalFileAndFolderChanges() async throws {
        let base = FileManager.default.temporaryDirectory.canonicalDirectoryURL
            .appendingPathComponent("frog-watch-\(UUID().uuidString)", isDirectory: true)
        let project = base.appendingPathComponent("project", isDirectory: true)
        let child = project.appendingPathComponent("child", isDirectory: true)
        try FileManager.default.createDirectory(at: child, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: base) }

        let paneID = "watch-\(UUID().uuidString)"
        defer {
            for key in ["layout", "showHiddenFiles", "currentDirectory", "expandedItems", "columns"] {
                UserDefaults.standard.removeObject(forKey: "pane.\(paneID).\(key)")
            }
        }

        let pane = PaneState(id: paneID, directory: project)
        await pane.loadTask?.value
        #expect(pane.items.map(\.name) == ["child"])

        let note = project.appendingPathComponent("note.txt")
        try Data("hi".utf8).write(to: note)
        try await waitForDirectoryChange {
            pane.items.contains { $0.name == "note.txt" && $0.size == 2 }
                && pane.visibleItems.contains { $0.item.name == "note.txt" && $0.item.size == 2 }
        }

        try Data("hello!".utf8).write(to: note)
        try await waitForDirectoryChange {
            pane.items.contains { $0.name == "note.txt" && $0.size == 6 }
                && pane.visibleItems.contains { $0.item.name == "note.txt" && $0.item.size == 6 }
        }

        try FileManager.default.createDirectory(
            at: project.appendingPathComponent("extra", isDirectory: true),
            withIntermediateDirectories: true
        )
        try await waitForDirectoryChange {
            pane.items.contains { $0.name == "extra" && $0.isDirectory }
        }

        pane.selection = [note]
        try FileManager.default.removeItem(at: note)
        try await waitForDirectoryChange {
            !pane.items.contains { $0.name == "note.txt" } && !pane.selection.contains(note)
        }

        let childItem = try #require(pane.items.first { $0.name == "child" })
        pane.toggleExpansion(for: childItem)
        try await waitForDirectoryChange {
            pane.itemChildren[childItem.url] != nil
        }
        try Data("x".utf8).write(to: child.appendingPathComponent("inside.txt"))
        try await waitForDirectoryChange {
            pane.visibleItems.contains { $0.item.name == "inside.txt" && $0.item.size == 1 }
        }

        try FileManager.default.removeItem(at: project)
        try await waitForDirectoryChange {
            pane.currentDirectory.canonicalDirectoryURL.path == base.canonicalDirectoryURL.path
                && pane.items.isEmpty
        }
    }
}

@MainActor
private func waitForDirectoryChange(
    timeoutNanoseconds: UInt64 = 5_000_000_000,
    condition: @escaping () -> Bool
) async throws {
    let deadline = DispatchTime.now().uptimeNanoseconds + timeoutNanoseconds
    while !condition() {
        if DispatchTime.now().uptimeNanoseconds >= deadline {
            throw DirectoryWatchWaitError.timedOut
        }
        try await Task.sleep(nanoseconds: 40_000_000)
    }
}

private enum DirectoryWatchWaitError: Error {
    case timedOut
}
