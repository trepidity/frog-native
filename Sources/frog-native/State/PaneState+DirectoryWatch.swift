import Foundation

extension PaneState {
    func startDirectoryMonitor() {
        let root = (soloRoot ?? currentDirectory).canonicalDirectoryURL
        if monitoredRoot == root.path, directoryMonitor != nil { return }
        monitoredRoot = root.path
        directoryMonitorGeneration += 1
        let generation = directoryMonitorGeneration
        pendingDirectoryEvents.removeAll()
        pendingDirectoryRescan = false
        directoryRefreshTask?.cancel()
        directoryMonitor?.stop()
        let target = DirectoryWatchTarget(self)
        let monitor = DirectoryChangeMonitor { paths, rescan in
            target.receive(paths: paths, rescan: rescan, generation: generation)
        }
        directoryMonitor = monitor
        monitor.start(rootPath: root.path)
    }

    func receiveDirectoryEvents(_ paths: [String], rescan: Bool) {
        pendingDirectoryEvents.append(contentsOf: paths)
        pendingDirectoryRescan = pendingDirectoryRescan || rescan
        directoryRefreshTask?.cancel()
        directoryRefreshTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: 80_000_000)
            guard let self, !Task.isCancelled else { return }
            let batch = self.pendingDirectoryEvents
            let rescanBatch = self.pendingDirectoryRescan
            self.pendingDirectoryEvents.removeAll()
            self.pendingDirectoryRescan = false
            self.applyDirectoryEvents(batch, rescan: rescanBatch)
        }
    }

    func applyDirectoryEvents(_ paths: [String], rescan: Bool) {
        let rootURL = (soloRoot ?? currentDirectory).canonicalDirectoryURL
        guard FileManager.default.fileExists(atPath: rootURL.path) else {
            if soloRoot != nil, FileManager.default.fileExists(atPath: currentDirectory.path) {
                exitSoloMode()
            } else {
                let parent = rootURL.deletingLastPathComponent()
                if parent.path != rootURL.path {
                    updateDirectory(parent)
                } else {
                    loadContents()
                }
            }
            return
        }

        let watched = watchedDirectoryPaths(root: rootURL)
        var affected: Set<String> = []
        if rescan {
            affected = watched
        } else {
            for path in paths {
                affected.formUnion(DirectoryEvents.affectedDirectories(eventPath: path, watched: watched))
            }
        }
        guard !affected.isEmpty else { return }

        if affected.contains(rootURL.path) {
            invalidateGitCache(for: rootURL)
            loadContents()
            let generation = loadGeneration
            Task {
                await loadTask?.value
                guard generation == self.loadGeneration else { return }
                self.dropMissingSelectionAndExpansion(root: rootURL)
            }
        }

        for expanded in expandedItems {
            let canonical = expanded.canonicalDirectoryURL
            guard canonical.path != rootURL.path, affected.contains(canonical.path) else { continue }
            invalidateGitCache(for: canonical)
            Task {
                guard FileManager.default.fileExists(atPath: expanded.path) else {
                    self.expandedItems.remove(expanded)
                    self.itemChildren[expanded] = nil
                    return
                }
                let children = await self.loadChildrenAsync(for: FileItem(url: expanded))
                guard self.expandedItems.contains(expanded) else { return }
                let currentRoot = (self.soloRoot ?? self.currentDirectory).canonicalDirectoryURL.path
                guard canonical.path == currentRoot || canonical.path.hasPrefix(currentRoot + "/") else { return }
                self.itemChildren[expanded] = children
            }
        }
    }

    func watchedDirectoryPaths(root: URL) -> Set<String> {
        var paths: Set<String> = [root.path]
        for url in expandedItems {
            let path = url.canonicalDirectoryURL.path
            if path == root.path || (root.path == "/" ? path != "/" : path.hasPrefix(root.path + "/")) {
                paths.insert(path)
            }
        }
        return paths
    }

    func invalidateGitCache(for directory: URL) {
        let path = directory.canonicalDirectoryURL.path
        for key in gitStatusCache.keys where key.canonicalDirectoryURL.path == path {
            gitStatusCache[key] = nil
        }
        for key in lastGitFetchTime.keys where key.canonicalDirectoryURL.path == path {
            lastGitFetchTime[key] = nil
        }
    }

    func dropMissingSelectionAndExpansion(root: URL) {
        selection = selection.filter { FileManager.default.fileExists(atPath: $0.path) }
        expandedItems = expandedItems.filter { url in
            let path = url.canonicalDirectoryURL.path
            let stillInside = path == root.path || (root.path == "/" ? path != "/" : path.hasPrefix(root.path + "/"))
            return stillInside && FileManager.default.fileExists(atPath: path)
        }
    }
}
