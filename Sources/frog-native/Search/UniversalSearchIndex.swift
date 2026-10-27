import Foundation
import Combine
import CoreServices

@MainActor
final class UniversalSearchIndex: ObservableObject {
    static let shared = UniversalSearchIndex()
    @Published private(set) var status = "Preparing search…"
    @Published private(set) var revision = 0
    @Published private(set) var isIndexing = true
    private(set) var index: FilenameIndex?
    private var events: SearchFileEvents?
    private var worker: Task<Void, Never>?
    private var pending = Set<String>()
    private var lastEvent: UInt64 = 0
    private var needsFullScan = false
    private var started = false
    private var deniedCount = 0
    private var cachePath = ""
    private var roots: [URL] = []

    func start() {
        guard !started else { return }
        started = true
        worker = Task { [self] in
            do {
                let manager = FileManager.default
                let cache = try manager.url(for: .applicationSupportDirectory, in: .userDomainMask,
                                            appropriateFor: nil, create: true)
                    .appendingPathComponent(Bundle.main.bundleIdentifier ?? "frog-native")
                    .appendingPathComponent("SearchIndex-v1", isDirectory: true)
                try manager.createDirectory(at: cache, withIntermediateDirectories: true, attributes: [.posixPermissions: 0o700])
                cachePath = cache.path
                let databaseURL = cache.appendingPathComponent("names.sqlite")
                let database = try FilenameIndex(url: databaseURL)
                try manager.setAttributes([.posixPermissions: 0o600], ofItemAtPath: databaseURL.path)
                index = database
                roots = [manager.homeDirectoryForCurrentUser.canonicalDirectoryURL, URL(fileURLWithPath: "/")]
                // A fixture scope is only used by the isolated QA app, never persisted as a user setting.
                if let fixture = ProcessInfo.processInfo.environment["FROG_SEARCH_ROOT"] {
                    roots = [URL(fileURLWithPath: fixture).canonicalDirectoryURL]
                }
                let savedScope = try await database.value(for: "scope")
                let scope = roots.map(\.path).joined(separator: "\n")
                let savedEvent = try await database.value(for: "event")
                if let savedScope, savedScope != scope { try await database.reset() }
                deniedCount = Int(try await database.value(for: "denied") ?? "0") ?? 0
                lastEvent = savedScope == scope ? (UInt64(savedEvent ?? "") ?? 0) : 0
                let dirty = try await database.value(for: "dirty") == "1"
                let initial = lastEvent == 0 || dirty
                if initial { lastEvent = FSEventsGetCurrentEventId() }
                events = try SearchFileEvents(roots: roots.map(\.path), since: lastEvent) { [weak self] paths, event, rebuild in
                    self?.receive(paths: paths, event: event, rebuild: rebuild)
                }
                needsFullScan = initial
                try await drain(database)
            } catch {
                needsFullScan = true
                status = "Filename index unavailable: \(error.localizedDescription)"
                isIndexing = false
            }
            worker = nil
        }
    }

    private func receive(paths: [String], event: UInt64, rebuild: Bool) {
        lastEvent = max(lastEvent, event)
        let logicalPaths = paths.map { path in
            let dataRoot = "/System/Volumes/Data"
            return path.hasPrefix(dataRoot + "/") ? String(path.dropFirst(dataRoot.count)) : path
        }
        let relevant = logicalPaths.filter { path in
            !path.hasPrefix(cachePath + "/") && path != cachePath &&
            !path.hasPrefix("/System/Volumes/") && !path.hasPrefix("/dev/")
        }
        guard !relevant.isEmpty || rebuild else { return }
        needsFullScan = needsFullScan || rebuild
        for raw in relevant {
            let path = URL(fileURLWithPath: raw).standardizedFileURL.path
            if pending.contains(where: { path == $0 || path.hasPrefix($0 + "/") }) { continue }
            pending = pending.filter { !$0.hasPrefix(path + "/") }
            pending.insert(path)
        }
        if pending.count > 512 { pending.removeAll(); needsFullScan = true }
        guard worker == nil, let index else { return }
        worker = Task { [self] in
            do { try await drain(index) }
            catch {
                needsFullScan = true
                status = "Search index update failed; retry on next change or restart."
                isIndexing = false
            }
            worker = nil
        }
    }

    private func drain(_ database: FilenameIndex) async throws {
        isIndexing = true
        while true {
            // A crash, cancellation, or failed write leaves this durable marker set.
            // The old event watermark is not sufficient proof of a complete index.
            try await database.setValue("1", for: "dirty")
            let full = needsFullScan
            needsFullScan = false
            let jobs = full ? roots : pending.sorted().map { URL(fileURLWithPath: $0) }
            pending.removeAll()
            if full { deniedCount = 0 }
            for root in jobs {
                try Task.checkCancellation()
                var exclusions: Set<String> = [cachePath, "/dev", "/Network", "/System/Volumes"]
                if root.path == "/", roots.count > 1 { exclusions.insert(roots[0].path) }
                status = "Indexing file and folder names…"
                let crawl = Task.detached(priority: .utility) {
                    try await SearchCrawler.scan(root: root, excluding: exclusions, into: database) { count in
                        await self.report(count)
                    }
                }
                let report = try await withTaskCancellationHandler { try await crawl.value } onCancel: { crawl.cancel() }
                deniedCount += report.denied
                revision += 1
            }
            if needsFullScan || !pending.isEmpty { continue }
            // Persist only an event watermark whose work has drained. Events arriving
            // during this actor hop must be processed before the worker goes idle.
            try await database.checkpoint(scope: roots.map(\.path).joined(separator: "\n"), event: lastEvent, denied: deniedCount)
            if !needsFullScan && pending.isEmpty { break }
        }
        isIndexing = false
        status = deniedCount > 0 ? "This Mac • some folders require access" : "This Mac • filename index ready"
    }

    private func report(_ count: Int) {
        status = "Indexing • \(count.formatted()) names scanned"
        revision += 1
    }

    func stop() {
        events?.stop()
        events = nil
        worker?.cancel()
    }
}
