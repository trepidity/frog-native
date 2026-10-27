import Foundation
import Testing
@testable import frog_native

struct PanePreferencesTests {
    @Test @MainActor func paneSettingsMigrateAndRemainIndependentAfterReopening() async throws {
        let suite = "frog-pane-preferences-\(UUID())"
        let preferences = try #require(UserDefaults(suiteName: suite))
        defer { preferences.removePersistentDomain(forName: suite) }
        preferences.set("Pro Table", forKey: "browser.currentLayout")
        preferences.set(true, forKey: "browser.showHiddenFiles")
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(suite)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }
        try Data().write(to: root.appendingPathComponent("visible.txt"))
        try Data().write(to: root.appendingPathComponent(".hidden.txt"))

        func open(_ id: String) async -> PaneState {
            let pane = PaneState(id: id, directory: root, preferences: preferences)
            pane.cancellables.removeAll()
            await pane.loadTask?.value
            return pane
        }
        let leftID = "\(suite)-left", rightID = "\(suite)-right"
        let left = await open(leftID), right = await open(rightID)
        #expect(left.currentLayout == .proTable)
        #expect(right.currentLayout == .proTable)
        left.currentLayout = .classic
        left.setHiddenFilesVisible(false)
        #expect(left.displayedItems.map(\.name) == ["visible.txt"])
        #expect(Set(right.displayedItems.map(\.name)) == [".hidden.txt", "visible.txt"])
        #expect(right.currentLayout == .proTable)
        right.currentLayout = .verticalTree
        #expect(left.currentLayout == .classic)

        // Old shared preferences must not override the migrated per-pane choices.
        preferences.set("Staircase Navigator", forKey: "browser.currentLayout")
        preferences.set(false, forKey: "browser.showHiddenFiles")
        let reopenedLeft = await open(leftID), reopenedRight = await open(rightID)
        #expect(reopenedLeft.currentLayout == .classic)
        #expect(reopenedRight.currentLayout == .verticalTree)
        #expect(reopenedLeft.displayedItems.map(\.name) == ["visible.txt"])
        #expect(Set(reopenedRight.displayedItems.map(\.name)) == [".hidden.txt", "visible.txt"])
    }
}
