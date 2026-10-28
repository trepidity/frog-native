import Foundation
import CoreServices

/// Watches the directory a pane has open and reports later filesystem changes.
///
/// `git status` rewrites files inside `.git`. Those events are ignored so a listing
/// refresh cannot schedule another refresh through its own Git process. Structural
/// appearance or disappearance of `.git` itself still counts.
final class DirectoryChangeMonitor: @unchecked Sendable {
    private let lock = NSLock()
    private var stream: FSEventStreamRef?
    private let queue = DispatchQueue(label: "frog.directory-events", qos: .utility)
    private let handler: @Sendable ([String], Bool) -> Void

    init(handler: @escaping @Sendable ([String], Bool) -> Void) {
        self.handler = handler
    }

    func start(rootPath: String) {
        stop()
        var context = FSEventStreamContext(
            version: 0,
            info: Unmanaged.passUnretained(self).toOpaque(),
            retain: nil,
            release: nil,
            copyDescription: nil
        )
        let callback: FSEventStreamCallback = { _, info, count, rawPaths, flags, _ in
            guard let info else { return }
            let monitor = Unmanaged<DirectoryChangeMonitor>.fromOpaque(info).takeUnretainedValue()
            let retained = Unmanaged.passRetained(monitor)
            defer { retained.release() }
            let reported = unsafeBitCast(rawPaths, to: NSArray.self) as? [String] ?? []
            let rescanMask = UInt32(
                kFSEventStreamEventFlagUserDropped |
                kFSEventStreamEventFlagKernelDropped |
                kFSEventStreamEventFlagEventIdsWrapped |
                kFSEventStreamEventFlagRootChanged |
                kFSEventStreamEventFlagMustScanSubDirs
            )
            var paths: [String] = []
            var rescan = false
            for index in 0..<count {
                let flag = flags[index]
                if flag & rescanMask != 0 { rescan = true }
                guard reported.indices.contains(index) else { continue }
                let path = reported[index]
                guard !DirectoryEvents.shouldIgnore(path: path, flags: flag) else { continue }
                paths.append(path)
            }
            guard rescan || !paths.isEmpty else { return }
            let deliver = monitor.handler
            deliver(paths, rescan)
        }
        guard let created = FSEventStreamCreate(
            nil,
            callback,
            &context,
            [rootPath] as CFArray,
            FSEventStreamEventId(kFSEventStreamEventIdSinceNow),
            0.15,
            UInt32(kFSEventStreamCreateFlagUseCFTypes | kFSEventStreamCreateFlagFileEvents | kFSEventStreamCreateFlagWatchRoot)
        ) else { return }
        lock.lock()
        stream = created
        lock.unlock()
        FSEventStreamSetDispatchQueue(created, queue)
        if !FSEventStreamStart(created) {
            stop()
        }
    }

    func stop() {
        lock.lock()
        let current = stream
        stream = nil
        lock.unlock()
        guard let current else { return }
        FSEventStreamStop(current)
        FSEventStreamInvalidate(current)
        FSEventStreamRelease(current)
    }

    deinit { stop() }
}

/// Forwards watch callbacks onto the pane without keeping the pane alive.
final class DirectoryWatchTarget: @unchecked Sendable {
    nonisolated(unsafe) weak var pane: PaneState?

    init(_ pane: PaneState) {
        self.pane = pane
    }

    func receive(paths: [String], rescan: Bool, generation: Int) {
        DispatchQueue.main.async { [weak self] in
            MainActor.assumeIsolated {
                guard let pane = self?.pane, pane.directoryMonitorGeneration == generation else { return }
                pane.receiveDirectoryEvents(paths, rescan: rescan)
            }
        }
    }
}

enum DirectoryEvents {
    static func shouldIgnore(path: String, flags: UInt32) -> Bool {
        let parts = path.split(separator: "/", omittingEmptySubsequences: true)
        guard let gitIndex = parts.firstIndex(of: ".git") else { return false }
        if gitIndex < parts.index(before: parts.endIndex) { return true }
        let structural = UInt32(
            kFSEventStreamEventFlagItemCreated |
            kFSEventStreamEventFlagItemRemoved |
            kFSEventStreamEventFlagItemRenamed
        )
        return flags & structural == 0
    }

    /// Directories whose visible rows can change because of this event path.
    static func affectedDirectories(eventPath: String, watched: Set<String>) -> Set<String> {
        var hits: Set<String> = []
        for variant in variants(of: eventPath) {
            if watched.contains(variant) { hits.insert(variant) }
            let parent = (variant as NSString).deletingLastPathComponent
            if watched.contains(parent) { hits.insert(parent) }
        }
        return hits
    }

    static func variants(of path: String) -> [String] {
        var results = [path]
        let dataRoot = "/System/Volumes/Data"
        if path == dataRoot {
            results.append("/")
        } else if path.hasPrefix(dataRoot + "/") {
            results.append(String(path.dropFirst(dataRoot.count)))
        }
        let originals = results
        for item in originals {
            if item.hasPrefix("/private/") {
                results.append(String(item.dropFirst("/private".count)))
            } else if item != "/" {
                results.append("/private" + item)
            }
        }
        return results
    }
}
