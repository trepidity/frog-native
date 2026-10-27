import Foundation
import Testing
import Darwin
@testable import frog_native

struct UniversalSearchTests {
    @Test func fileEventsIndexSymlinkNamesWithoutFollowingTargets() async throws {
        let root = try fixture(), storage = try fixture()
        defer { try? FileManager.default.removeItem(at: root); try? FileManager.default.removeItem(at: storage) }
        let target = storage.appendingPathComponent("elsewhere-target.txt")
        try Data().write(to: target)
        let link = root.appendingPathComponent("new-link-name")
        try FileManager.default.createSymbolicLink(at: link, withDestinationURL: target)
        let index = try FilenameIndex(url: storage.appendingPathComponent("index.sqlite"))
        _ = try await SearchCrawler.scan(root: link, excluding: [], into: index)
        #expect(try await index.search("new-link-name").map(\.url.path) == [link.path])
        #expect(try await index.search("elsewhere-target").isEmpty)
        try FileManager.default.removeItem(at: link)
        _ = try await SearchCrawler.scan(root: link, excluding: [], into: index)
        #expect(try await index.search("new-link-name").isEmpty)
    }

    @Test func scopeResetCannotLeaveAnEmptyIndexMarkedComplete() async throws {
        let root = try fixture()
        defer { try? FileManager.default.removeItem(at: root) }
        let database = root.appendingPathComponent("index.sqlite")
        let index = try FilenameIndex(url: database)
        try await index.checkpoint(scope: "/old", event: 123, denied: 0)
        try await index.reset()
        // Simulate interruption immediately after reset, before the replacement crawl.
        let reopened = try FilenameIndex(url: database)
        #expect(try await reopened.value(for: "dirty") == "1")
        #expect(try await reopened.value(for: "scope") == "/old")
        #expect(try await reopened.value(for: "event") == "123")
    }

    @Test(.enabled(if: geteuid() != 0)) func deniedDirectoryIsNotTreatedAsDeleted() async throws {
        let root = try fixture(), storage = try fixture()
        let gate = root.appendingPathComponent("gate"), child = gate.appendingPathComponent("child")
        defer {
            try? FileManager.default.setAttributes([.posixPermissions: 0o700], ofItemAtPath: gate.path)
            try? FileManager.default.removeItem(at: root)
            try? FileManager.default.removeItem(at: storage)
        }
        try FileManager.default.createDirectory(at: child, withIntermediateDirectories: true)
        try Data().write(to: child.appendingPathComponent("protected-target.txt"))
        let index = try FilenameIndex(url: storage.appendingPathComponent("index.sqlite"))
        _ = try await SearchCrawler.scan(root: root, excluding: [], into: index)
        try FileManager.default.setAttributes([.posixPermissions: 0], ofItemAtPath: gate.path)
        let report = try await SearchCrawler.scan(root: child, excluding: [], into: index)
        #expect(report.denied == 1)
        #expect(try await index.search("protected-target").map(\.name) == ["protected-target.txt"])
    }

    @Test func supersededIndexQueryStopsWork() async throws {
        let root = try fixture()
        defer { try? FileManager.default.removeItem(at: root) }
        let index = try FilenameIndex(url: root.appendingPathComponent("index.sqlite"))
        let work = Task {
            withUnsafeCurrentTask { $0?.cancel() }
            do {
                _ = try await index.search("target")
                return false
            } catch is CancellationError { return true }
        }
        #expect(try await work.value)
    }

    // Durable filename-index contract: literal matching, case/diacritic folding, hidden
    // names, bounded short queries, and exact-match ranking survive a process reopening.
    @Test func persistedIndexFindsNamesAndRanksExactMatches() async throws {
        let root = try fixture()
        defer { try? FileManager.default.removeItem(at: root) }
        let database = root.appendingPathComponent("index.sqlite")
        let writer = try FilenameIndex(url: database)
        let names = [".aurora", "Aurora", "aurora-report.txt", "prefix-aurora-notes.md", "Café.txt", "literal[1]*.txt", "quoted\"name.txt"]
        try await writer.upsert(names.map {
            SearchEntry(url: URL(fileURLWithPath: "/fixture/" + $0), isDirectory: $0 == ".aurora")
        }, generation: "fixture")
        let reader = try FilenameIndex(url: database)
        for (query, expected) in [
            ("AURORA", [".aurora", "Aurora", "aurora-report.txt", "prefix-aurora-notes.md"]),
            ("ca", ["Café.txt"]), ("cafe", ["Café.txt"]),
            ("[1]*", ["literal[1]*.txt"]), ("quoted\"", ["quoted\"name.txt"]), ("absent", [])
        ] {
            let result = try await reader.search(query)
            #expect(result.map(\.name) == expected, "Query: \(query)")
        }
    }

    // Filesystem -> durable index boundary: catches hidden/package exclusions,
    // symlink loops, and stale descendants after rename/delete.
    @Test func crawlingTracksHiddenFilesPackagesAndRenames() async throws {
        let root = try fixture(), storage = try fixture()
        defer { try? FileManager.default.removeItem(at: root); try? FileManager.default.removeItem(at: storage) }
        let hidden = root.appendingPathComponent(".secret", isDirectory: true)
        let package = root.appendingPathComponent("Example.app/Contents", isDirectory: true)
        try FileManager.default.createDirectory(at: hidden, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: package, withIntermediateDirectories: true)
        try Data().write(to: hidden.appendingPathComponent("target.txt"))
        try Data().write(to: package.appendingPathComponent("target.bin"))
        try FileManager.default.createSymbolicLink(at: hidden.appendingPathComponent("loop"), withDestinationURL: root)
        let index = try FilenameIndex(url: storage.appendingPathComponent("index.sqlite"))
        _ = try await SearchCrawler.scan(root: root, excluding: [], into: index)
        #expect(try await index.search("target").map(\.name).sorted() == ["target.bin", "target.txt"])
        #expect(try await index.search("secret").map(\.name) == [".secret"])
        let renamed = root.appendingPathComponent("renamed", isDirectory: true)
        try FileManager.default.moveItem(at: hidden, to: renamed)
        try FileManager.default.removeItem(at: root.appendingPathComponent("Example.app"))
        _ = try await SearchCrawler.scan(root: root, excluding: [], into: index)
        let actual = try await index.search("target").map(\.url.path)
        #expect(actual == [renamed.appendingPathComponent("target.txt").path])
        #expect(try await index.search("secret").isEmpty)
    }

    @Test @MainActor func globalJumpLeavesSoloAndSelectsAfterLoading() async throws {
        let root = try fixture()
        defer { try? FileManager.default.removeItem(at: root) }
        let outside = root.appendingPathComponent("outside", isDirectory: true)
        let inside = root.appendingPathComponent("inside", isDirectory: true)
        try FileManager.default.createDirectory(at: inside, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: outside, withIntermediateDirectories: true)
        let file = outside.appendingPathComponent("target.txt")
        try Data().write(to: file)
        let id = "search-test-\(UUID())"
        defer { UserDefaults.standard.removeObject(forKey: "pane.\(id).currentDirectory") }
        let pane = PaneState(id: id, directory: inside)
        pane.soloRoot = inside
        pane.mode = .helpGuide
        pane.jump(to: SearchEntry(url: file, isDirectory: false))
        try await eventually { !pane.isPathLoading && pane.selection.contains { $0.path == file.path } }
        #expect(pane.currentDirectory.path == outside.path)
        #expect(pane.mode == .browser)
        #expect(pane.soloRoot == nil)
        #expect(pane.visibleItems.contains { $0.item.url.path == file.path })
        pane.navigateBack()
        #expect(pane.currentDirectory.path == inside.path)
        // A newer navigation must defeat an in-flight search reveal.
        pane.jump(to: SearchEntry(url: file, isDirectory: false))
        pane.jump(to: SearchEntry(url: inside, isDirectory: true))
        try await eventually { !pane.isPathLoading }
        #expect(pane.currentDirectory.path == inside.path)
        #expect(pane.selection.isEmpty)
    }

    @Test @MainActor func breadcrumbsCarryRealURLsAndExitSoloAtSameRoot() async throws {
        let root = try fixture()
        defer { try? FileManager.default.removeItem(at: root) }
        let nested = root.appendingPathComponent("same/same", isDirectory: true)
        try FileManager.default.createDirectory(at: nested, withIntermediateDirectories: true)
        let pane = PaneState(id: "breadcrumb-\(UUID())", directory: root)
        pane.items = [FileItem(url: nested)]
        pane.selection = [nested]
        #expect(pane.breadcrumbs.map(\.path) == [root.path, root.appendingPathComponent("same").path, nested.path])
        try #require(pane.breadcrumbs.count == 3)
        pane.updateDirectory(pane.breadcrumbs[1])
        #expect(pane.currentDirectory.path == root.appendingPathComponent("same").path)
        pane.soloRoot = nested
        pane.updateDirectory(pane.currentDirectory)
        #expect(pane.soloRoot == nil)
        try await eventually { !pane.isPathLoading }
        pane.cancellables.removeAll()
    }

    @Test @MainActor func rapidPathQueriesCannotPublishOldResults() async throws {
        let root = try fixture()
        defer { try? FileManager.default.removeItem(at: root) }
        try Data().write(to: root.appendingPathComponent("alpha.txt"))
        try Data().write(to: root.appendingPathComponent("beta.txt"))
        let session = UniversalSearchSession()
        defer { session.cancel() }
        session.search(root.path + "/alpha", index: nil)
        session.search(root.path + "/beta", index: nil)
        try await eventually { !session.isSearching }
        #expect(session.results.map(\.name) == ["beta.txt"])
        session.search(root.path + "/alpha", index: nil)
        session.search("", index: nil)
        try await Task.sleep(for: .milliseconds(30))
        #expect(session.results.isEmpty)
        #expect(!session.isSearching)
    }
}

private func fixture() throws -> URL {
    let url = FileManager.default.temporaryDirectory.canonicalDirectoryURL.appendingPathComponent("frog-search-\(UUID())", isDirectory: true)
    try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
    return url
}

@MainActor private func eventually(_ condition: () -> Bool) async throws {
    let deadline = ContinuousClock.now + .seconds(5)
    while !condition() {
        guard ContinuousClock.now < deadline else { throw CocoaError(.coderInvalidValue) }
        try await Task.sleep(for: .milliseconds(10))
    }
}
