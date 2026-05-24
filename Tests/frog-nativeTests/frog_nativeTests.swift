import Foundation
import AppKit
import Testing
@testable import frog_native

struct PaneStateTests {
    @Test
    @MainActor
    func visibleItemsRefreshesWhenExpandedBranchChanges() throws {
        let root = try makeTemporaryTree()

        let state = PaneState(id: uniquePaneID(), directory: root)
        let alpha = FileItem(url: root.appendingPathComponent("alpha", isDirectory: true))
        let beta = FileItem(url: root.appendingPathComponent("beta", isDirectory: true))

        state.items = [alpha, beta]
        state.itemChildren = [
            alpha.url: [FileItem(url: alpha.url.appendingPathComponent("a.txt"))],
            beta.url: [FileItem(url: beta.url.appendingPathComponent("b.txt"))],
        ]

        state.expandedItems = [alpha.url]
        #expect(state.visibleItems.map(\.item.name) == ["alpha", "a.txt", "beta"])

        state.expandedItems = [beta.url]
        #expect(state.visibleItems.map(\.item.name) == ["alpha", "beta", "b.txt"])
    }

    @Test
    @MainActor
    func restoredExpandedItemsLoadChildrenAsynchronously() async throws {
        let root = try makeTemporaryTree()
        let alpha = root.appendingPathComponent("alpha", isDirectory: true)
        let paneID = uniquePaneID()
        let expandedKey = "pane.\(paneID).expandedItems"

        UserDefaults.standard.set([alpha.path], forKey: expandedKey)
        defer {
            UserDefaults.standard.removeObject(forKey: expandedKey)
        }

        let state = PaneState(id: paneID, directory: root)

        #expect(state.expandedItems == Set([alpha]))
        try await waitUntil {
            state.itemChildren[alpha]?.map(\.name) == ["a.txt"]
        }
    }

    @Test
    func imageDimensionsUseQADisplayFormat() throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("frog-native-image-tests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)

        let imageURL = root.appendingPathComponent("sample.png")
        try writePNG(width: 2, height: 3, to: imageURL)

        let item = FileItem(url: imageURL)
        #expect(item.dimensions == "2×3 px")
    }

    @Test
    func existingURLsForTrashSkipsMissingPaths() throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("frog-native-trash-tests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)

        let existing = root.appendingPathComponent("present.txt")
        let missing = root.appendingPathComponent("missing.txt")
        FileManager.default.createFile(atPath: existing.path, contents: Data("ok".utf8))

        let filtered = PaneState.existingURLsForTrash(in: [existing, missing])
        #expect(filtered == [existing])
    }
}

private func makeTemporaryTree() throws -> URL {
    let root = FileManager.default.temporaryDirectory
        .appendingPathComponent("frog-native-tests-\(UUID().uuidString)", isDirectory: true)
    let alpha = root.appendingPathComponent("alpha", isDirectory: true)
    let beta = root.appendingPathComponent("beta", isDirectory: true)

    try FileManager.default.createDirectory(at: alpha, withIntermediateDirectories: true)
    try FileManager.default.createDirectory(at: beta, withIntermediateDirectories: true)
    FileManager.default.createFile(atPath: alpha.appendingPathComponent("a.txt").path, contents: Data("a".utf8))
    FileManager.default.createFile(atPath: beta.appendingPathComponent("b.txt").path, contents: Data("b".utf8))

    return root
}

private func uniquePaneID() -> String {
    "test-\(UUID().uuidString)"
}

private func writePNG(width: Int, height: Int, to url: URL) throws {
    let bytesPerRow = width * 4
    let bitmap = NSBitmapImageRep(
        bitmapDataPlanes: nil,
        pixelsWide: width,
        pixelsHigh: height,
        bitsPerSample: 8,
        samplesPerPixel: 4,
        hasAlpha: true,
        isPlanar: false,
        colorSpaceName: .deviceRGB,
        bytesPerRow: bytesPerRow,
        bitsPerPixel: 32
    )

    guard let bitmap else {
        throw TestError.bitmapCreationFailed
    }

    guard let data = bitmap.representation(using: .png, properties: [:]) else {
        throw TestError.pngEncodingFailed
    }

    try data.write(to: url)
}

@MainActor
private func waitUntil(
    timeoutNanoseconds: UInt64 = 2_000_000_000,
    pollIntervalNanoseconds: UInt64 = 20_000_000,
    condition: @escaping () -> Bool
) async throws {
    let deadline = DispatchTime.now().uptimeNanoseconds + timeoutNanoseconds

    while !condition() {
        if DispatchTime.now().uptimeNanoseconds >= deadline {
            throw WaitError.timedOut
        }

        try await Task.sleep(nanoseconds: pollIntervalNanoseconds)
    }
}

private enum WaitError: Error {
    case timedOut
}

private enum TestError: Error {
    case bitmapCreationFailed
    case pngEncodingFailed
}
