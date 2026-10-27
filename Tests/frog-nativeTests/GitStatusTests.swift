import Foundation
import Testing
@testable import frog_native

struct GitStatusTests {
    @Test(arguments: [false, true]) @MainActor
    func nestedFolderStatusUsesRepositoryRelativePaths(separateGitDirectory: Bool) async throws {
        let root = FileManager.default.temporaryDirectory.canonicalDirectoryURL
            .appendingPathComponent("frog-git-\(UUID())")
        let nested = root.appendingPathComponent("nested")
        try FileManager.default.createDirectory(at: nested, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }
        try Data("fixture".utf8).write(to: nested.appendingPathComponent("tracked.txt"))
        #expect(PaneState.gitRepositoryRoot(containing: nested) == nil)
        let metadata = root.appendingPathComponent("git-metadata")
        let flags = separateGitDirectory ? ["--separate-git-dir", metadata.path] : []
        try git(["init", "--quiet"] + flags + [root.path])
        #expect(PaneState.gitRepositoryRoot(containing: nested)?.path == root.path)
        try git(["-C", root.path, "add", "nested/tracked.txt"])
        let pane = PaneState(id: "git-test-\(UUID())", directory: nested)
        defer { pane.cancellables.removeAll(); pane.loadTask?.cancel() }
        let result = await pane.getCachedGitStatus(for: nested)
        #expect(result[nested.appendingPathComponent("tracked.txt").path] == .added)
        #expect(result[nested.appendingPathComponent("nested/tracked.txt").path] == nil)
    }
}

private func git(_ arguments: [String]) throws {
    let process = Process()
    process.executableURL = URL(fileURLWithPath: "/usr/bin/git")
    process.arguments = arguments
    process.standardOutput = FileHandle.nullDevice
    process.standardError = FileHandle.nullDevice
    try process.run()
    process.waitUntilExit()
    try #require(process.terminationStatus == 0)
}
