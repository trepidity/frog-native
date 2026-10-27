import Foundation
import Combine

@MainActor
final class UniversalSearchSession: NSObject, ObservableObject {
    @Published private(set) var results: [SearchEntry] = []
    @Published private(set) var isSearching = false
    @Published private(set) var errorMessage: String?
    private var query: NSMetadataQuery?
    private var task: Task<Void, Never>?
    private var generation = 0
    private var text = ""
    private var indexed: [SearchEntry] = []
    private var spotlight: [SearchEntry] = []
    private var localPending = false
    private var spotlightPending = false

    func search(_ text: String, index: FilenameIndex?) {
        cancel()
        self.text = text.trimmingCharacters(in: .whitespacesAndNewlines)
        results = []
        indexed = []
        spotlight = []
        errorMessage = nil
        guard !self.text.isEmpty else { return }
        let needle = self.text
        let version = generation
        isSearching = true
        localPending = true
        let direct = needle.hasPrefix("/") || needle.hasPrefix("~")
        if !direct { startSpotlight(needle) }
        task = Task {
            do {
                let matches: [SearchEntry]
                if direct {
                    let work = Task.detached(priority: .userInitiated) { try SearchEntry.directPathMatches(needle) }
                    matches = try await withTaskCancellationHandler { try await work.value } onCancel: { work.cancel() }
                } else {
                    matches = try await index?.search(needle) ?? []
                }
                guard !Task.isCancelled, generation == version else { return }
                indexed = matches
            } catch {
                guard !Task.isCancelled, generation == version else { return }
                errorMessage = direct ? "Cannot read this path: \(error.localizedDescription)" : "Filename index unavailable; using Spotlight."
            }
            guard !Task.isCancelled, generation == version else { return }
            localPending = false
            publish()
        }
    }

    /// Refresh only the local layer as the initial index grows; keep the live Spotlight query.
    func refresh(index: FilenameIndex?) {
        guard !text.isEmpty, !text.hasPrefix("/"), !text.hasPrefix("~"), let index else { return }
        task?.cancel()
        let version = generation, needle = text
        task = Task {
            do {
                let matches = try await index.search(needle)
                guard !Task.isCancelled, generation == version else { return }
                indexed = matches
                localPending = false
                publish()
            } catch {
                guard generation == version else { return }
                errorMessage = "Filename index unavailable; using Spotlight."
            }
        }
    }

    private func startSpotlight(_ text: String) {
        let query = NSMetadataQuery()
        self.query = query
        query.searchScopes = [NSMetadataQueryIndexedLocalComputerScope]
        query.predicate = NSPredicate(format: text.count < 3 ? "%K BEGINSWITH[cd] %@" : "%K CONTAINS[cd] %@",
                                      NSMetadataItemFSNameKey, text)
        query.sortDescriptors = [NSSortDescriptor(key: NSMetadataItemFSNameKey, ascending: true)]
        query.notificationBatchingInterval = 0.05
        for name in [NSNotification.Name.NSMetadataQueryDidUpdate, NSNotification.Name.NSMetadataQueryGatheringProgress,
                     NSNotification.Name.NSMetadataQueryDidFinishGathering] {
            NotificationCenter.default.addObserver(self, selector: #selector(spotlightUpdated(_:)), name: name, object: query)
        }
        spotlightPending = query.start()
        if !spotlightPending { errorMessage = "Spotlight unavailable; using the filename index." }
    }

    @objc private func spotlightUpdated(_ notification: Notification) {
        guard let query, notification.object as? NSMetadataQuery === query else { return }
        query.disableUpdates()
        var matches: [SearchEntry] = []
        for i in 0..<min(query.resultCount, 400) {
            guard let item = query.result(at: i) as? NSMetadataItem,
                  let path = item.value(forAttribute: NSMetadataItemPathKey) as? String else { continue }
            let type = item.value(forAttribute: NSMetadataItemContentTypeKey) as? String
            let types = item.value(forAttribute: NSMetadataItemContentTypeTreeKey) as? [String] ?? []
            matches.append(SearchEntry(url: URL(fileURLWithPath: path), isDirectory: type == "public.folder" || types.contains("public.directory")))
        }
        query.enableUpdates()
        spotlight = matches
        if notification.name == NSNotification.Name.NSMetadataQueryDidFinishGathering { spotlightPending = false }
        publish()
    }

    private func publish() {
        // Path identity merges URL representations with/without a directory trailing slash.
        let unique = Dictionary((spotlight + indexed).map { ($0.id, $0) }, uniquingKeysWith: { _, newer in newer })
        results = SearchEntry.ranked(Array(unique.values), query: text)
        isSearching = localPending || spotlightPending
    }

    func cancel() {
        generation += 1
        task?.cancel()
        task = nil
        if let query {
            query.stop()
            NotificationCenter.default.removeObserver(self, name: nil, object: query)
        }
        query = nil
        localPending = false
        spotlightPending = false
        isSearching = false
    }
}
