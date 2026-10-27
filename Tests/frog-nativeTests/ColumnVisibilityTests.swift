import Foundation
import Testing
@testable import frog_native

struct ColumnVisibilityTests {
    @Test @MainActor func columnChoicesStayAlignedIndependentAndPersisted() async throws {
        let suite = "frog-column-visibility-\(UUID())"
        let preferences = try #require(UserDefaults(suiteName: suite))
        defer { preferences.removePersistentDomain(forName: suite) }
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(suite)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }
        func open(_ id: String) async -> PaneState {
            let pane = PaneState(id: id, directory: root, preferences: preferences)
            pane.cancellables.removeAll()
            await pane.loadTask?.value
            return pane
        }
        let left = await open("\(suite)-left"), right = await open("\(suite)-right")
        #expect(left.displayedColumns.map(\.title) == ["Name", "Created", "Modified", "Size"])
        left.setColumnVisible(.created, false)
        left.setColumnVisible(.dimensions, true)
        left.setColumnVisible(.name, false)
        #expect(left.displayedColumns.map(\.title) == ["Name", "Modified", "Dimensions", "Size"])
        #expect(right.displayedColumns.map(\.title) == ["Name", "Created", "Modified", "Size"])
        let restored = await open("\(suite)-left")
        restored.currentLayout = .proTable
        #expect(restored.displayedColumns.map(\.title) == ["Name", "Modified", "Dimensions", "Size"])
        restored.resetColumns()
        #expect(restored.displayedColumns.map(\.title) == ["Name", "Modified", "Size"])
        restored.currentLayout = .verticalTree
        restored.context = .assets
        #expect(restored.displayedColumns.map(\.title) == ["Name", "Dimensions", "Type", "Size"])
    }
}
