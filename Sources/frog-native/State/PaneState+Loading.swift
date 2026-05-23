import Foundation
import AppKit

extension PaneState {
    nonisolated static let directoryEnumerationKeys: [URLResourceKey] = [
        .isDirectoryKey,
        .fileSizeKey,
        .contentModificationDateKey,
        .creationDateKey
    ]

    func loadContents() {
        let targetDirectory = soloRoot ?? currentDirectory
        let sortField = self.sortField
        let sortOrder = self.sortOrder
        let previousItems = Set(self.items.map { $0.url })

        loadTask?.cancel()
        loadGeneration += 1
        let generation = loadGeneration
        isPathLoading = true

        loadTask = Task(priority: .userInitiated) {
            await self.performLoad(
                directory: targetDirectory,
                sortField: sortField,
                sortOrder: sortOrder,
                previousItems: previousItems,
                generation: generation
            )
        }
    }

    private func performLoad(
        directory: URL,
        sortField: SortField,
        sortOrder: SortOrder,
        previousItems: Set<URL>,
        generation: Int
    ) async {
        do {
            let gitStatuses = await getCachedGitStatus(for: directory)
            let (newItems, newContext) = try await Self.fetchAndSort(
                directory: directory,
                gitStatuses: gitStatuses,
                sortField: sortField,
                sortOrder: sortOrder
            )
            guard !Task.isCancelled else { return }
            applyLoadResult(
                newItems: newItems,
                newContext: newContext,
                previousItems: previousItems,
                generation: generation
            )
        } catch is CancellationError {
            if generation == self.loadGeneration {
                self.loadTask = nil
            }
        } catch {
            print("Error loading directory \(directory): \(error)")
            guard generation == self.loadGeneration else { return }
            self.items = []
            self.isPathLoading = false
            self.loadTask = nil
        }
    }

    private static func fetchAndSort(
        directory: URL,
        gitStatuses: [String: FileItem.GitStatus],
        sortField: SortField,
        sortOrder: SortOrder
    ) async throws -> ([FileItem], FolderContext) {
        try await Task.detached(priority: .userInitiated) {
            try Task.checkCancellation()
            let manager = FileManager.default
            let urls = try manager.contentsOfDirectory(
                at: directory,
                includingPropertiesForKeys: directoryEnumerationKeys,
                options: .skipsHiddenFiles
            )
            try Task.checkCancellation()
            let items = urls.map { url -> FileItem in
                var item = FileItem(url: url)
                item.gitStatus = gitStatuses[url.path] ?? .clean
                return item
            }
            let sorted = sortItems(items, field: sortField, order: sortOrder)
            let imageCount = items.filter { $0.isImage }.count
            let ratio = Double(imageCount) / Double(max(1, items.count))
            let context: FolderContext = ratio > 0.4 ? .assets : .standard
            return (sorted, context)
        }.value
    }

    private func applyLoadResult(
        newItems: [FileItem],
        newContext: FolderContext,
        previousItems: Set<URL>,
        generation: Int
    ) {
        guard generation == self.loadGeneration else { return }
        for item in newItems where !previousItems.contains(item.url) {
            self.recentArrivals[item.url] = Date()
            Task {
                try? await Task.sleep(nanoseconds: 5_000_000_000)
                self.recentArrivals.removeValue(forKey: item.url)
            }
        }
        self.items = newItems
        self.context = newContext
        self.isPathLoading = false
        self.loadTask = nil
    }

    func getCachedGitStatus(for directory: URL) async -> [String: FileItem.GitStatus] {
        if let lastFetch = lastGitFetchTime[directory], Date().timeIntervalSince(lastFetch) < 2.0 {
            return gitStatusCache[directory] ?? [:]
        }
        let statuses = await Self.fetchGitStatus(for: directory)
        gitStatusCache[directory] = statuses
        lastGitFetchTime[directory] = Date()
        return statuses
    }

    nonisolated private static func fetchGitStatus(for directory: URL) async -> [String: FileItem.GitStatus] {
        await Task.detached(priority: .utility) {
            let process = Process()
            process.executableURL = URL(fileURLWithPath: "/usr/bin/git")
            process.arguments = ["status", "--porcelain"]
            process.currentDirectoryURL = directory

            let pipe = Pipe()
            process.standardOutput = pipe

            do {
                try process.run()
                let data = pipe.fileHandleForReading.readDataToEndOfFile()
                guard let output = String(data: data, encoding: .utf8) else { return [:] }
                return parseGitStatus(output: output, directory: directory)
            } catch {
                return [:]
            }
        }.value
    }

    nonisolated private static func parseGitStatus(
        output: String,
        directory: URL
    ) -> [String: FileItem.GitStatus] {
        var statuses: [String: FileItem.GitStatus] = [:]
        let lines = output.components(separatedBy: "\n")
        for line in lines where line.count > 3 {
            let statusPart = line.prefix(2)
            let pathPart = String(line.dropFirst(3))
            let fullPath = directory.appendingPathComponent(pathPart).path

            let status: FileItem.GitStatus
            switch statusPart {
            case " M", "M ": status = .modified
            case " A", "A ": status = .added
            case " D", "D ": status = .deleted
            case "??": status = .untracked
            default: status = .clean
            }
            statuses[fullPath] = status
        }
        return statuses
    }

    func refresh() {
        gitStatusCache.removeAll()
        lastGitFetchTime.removeAll()
        loadContents()
        refreshExpandedItems()
    }

    func refreshExpandedItems() {
        for url in expandedItems {
            Task {
                let item = FileItem(url: url)
                let children = await loadChildrenAsync(for: item)
                self.itemChildren[url] = children
            }
        }
    }

    func loadChildren(for item: FileItem) -> [FileItem] {
        loadChildrenSync(for: item)
    }

    func loadChildrenSync(for item: FileItem) -> [FileItem] {
        guard item.isDirectory else { return [] }
        let urls = (try? FileManager.default.contentsOfDirectory(
            at: item.url,
            includingPropertiesForKeys: Self.directoryEnumerationKeys,
            options: .skipsHiddenFiles
        )) ?? []
        return Self.sortItems(
            urls.map { FileItem(url: $0) },
            field: sortField,
            order: sortOrder
        )
    }

    func loadChildrenAsync(for item: FileItem) async -> [FileItem] {
        guard item.isDirectory else { return [] }
        let sortField = self.sortField
        let sortOrder = self.sortOrder
        let gitStatuses = await getCachedGitStatus(for: item.url)
        let itemURL = item.url

        return await Task.detached(priority: .userInitiated) {
            let manager = FileManager.default
            let urls = (try? manager.contentsOfDirectory(
                at: itemURL,
                includingPropertiesForKeys: PaneState.directoryEnumerationKeys,
                options: .skipsHiddenFiles
            )) ?? []
            let items = urls.map { url -> FileItem in
                var child = FileItem(url: url)
                child.gitStatus = gitStatuses[url.path] ?? .clean
                return child
            }
            return PaneState.sortItems(items, field: sortField, order: sortOrder)
        }.value
    }

    nonisolated static func sortItems(
        _ items: [FileItem],
        field: SortField,
        order: SortOrder
    ) -> [FileItem] {
        items.sorted { lhs, rhs in
            if lhs.isDirectory != rhs.isDirectory {
                return lhs.isDirectory
            }
            let result: Bool
            switch field {
            case .name:
                result = lhs.name.localizedCompare(rhs.name) == .orderedAscending
            case .created:
                result = lhs.creationDate < rhs.creationDate
            case .modified:
                result = lhs.modificationDate < rhs.modificationDate
            }
            return order == .ascending ? result : !result
        }
    }
}
