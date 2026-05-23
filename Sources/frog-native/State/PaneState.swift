import Foundation
import Combine
import AppKit

enum SortField {
    case name
    case created
    case modified
}

enum SortOrder {
    case ascending
    case descending
}

enum PaneMode: Equatable {
    case browser
    case editor(URL)
    case helpGuide
}

struct VisibleTreeItem: Identifiable {
    var id: URL { item.url }
    let item: FileItem
    let level: Int
    let parentLineStates: [Bool]
    let isLast: Bool
}

@MainActor
class PaneState: ObservableObject {
    let id: String
    @Published var currentDirectory: URL
    @Published var mode: PaneMode = .browser
    @Published var items: [FileItem] = []
    @Published var selection: Set<URL> = []
    
    @Published var expandedItems: Set<URL> = []
    @Published var itemChildren: [URL: [FileItem]] = [:]
    
    @Published var sortField: SortField = .name
    @Published var sortOrder: SortOrder = .ascending
    
    @Published var backStack: [URL] = []
    @Published var forwardStack: [URL] = []
    
    @Published var previewURL: URL? = nil
    @Published var soloRoot: URL? = nil
    @Published var isPathLoading: Bool = false
    
    @Published var context: FolderContext = .standard
    @Published var recentArrivals: [URL: Date] = [:]

    enum FolderContext {
        case standard
        case assets
    }

    private var cancellables = Set<AnyCancellable>()
    private var loadTask: Task<Void, Never>?
    private var loadGeneration: Int = 0
    
    private var gitStatusCache: [URL: [String: FileItem.GitStatus]] = [:]
    private var lastGitFetchTime: [URL: Date] = [:]
    
    static let shouldRefreshPanes = Notification.Name("shouldRefreshPanes")
    
    init(id: String, directory: URL) {
        self.id = id
        
        if let savedPath = UserDefaults.standard.string(forKey: "pane.\(id).currentDirectory"),
           FileManager.default.fileExists(atPath: savedPath) {
            self.currentDirectory = URL(fileURLWithPath: savedPath)
        } else {
            self.currentDirectory = directory
        }
        
        if let savedExpanded = UserDefaults.standard.stringArray(forKey: "pane.\(id).expandedItems") {
            self.expandedItems = Set(savedExpanded.map { URL(fileURLWithPath: $0) })
            for url in self.expandedItems {
                let item = FileItem(url: url)
                self.itemChildren[url] = loadChildrenSync(for: item)
            }
        }
        
        loadContents()
        
        NotificationCenter.default.publisher(for: Self.shouldRefreshPanes)
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                self?.refresh()
            }
            .store(in: &cancellables)
        
        Publishers.CombineLatest3($currentDirectory, $sortField, $sortOrder)
            .debounce(for: .milliseconds(50), scheduler: RunLoop.main)
            .dropFirst()
            .sink { [weak self] _, _, _ in
                guard let self = self else { return }
                self.loadContents()
                self.refreshExpandedItems()
            }
            .store(in: &cancellables)
            
        $currentDirectory
            .dropFirst()
            .sink { [weak self] url in
                guard let self = self else { return }
                UserDefaults.standard.set(url.path, forKey: "pane.\(self.id).currentDirectory")
            }
            .store(in: &cancellables)
            
        $expandedItems
            .dropFirst()
            .sink { [weak self] urls in
                guard let self = self else { return }
                let paths = urls.map { $0.path }
                UserDefaults.standard.set(paths, forKey: "pane.\(self.id).expandedItems")
            }
            .store(in: &cancellables)
    }
    
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
            let manager = FileManager.default
            let keys: [URLResourceKey] = [.isDirectoryKey, .fileSizeKey, .contentModificationDateKey, .creationDateKey]
            
            do {
                let gitStatuses = await self.getCachedGitStatus(for: targetDirectory)
                
                let (newItems, newContext) = try await Task.detached(priority: .userInitiated) {
                    try Task.checkCancellation()
                    let urls = try manager.contentsOfDirectory(at: targetDirectory, includingPropertiesForKeys: keys, options: .skipsHiddenFiles)

                    try Task.checkCancellation()
                    let items = urls.map { url in
                        var item = FileItem(url: url)
                        item.gitStatus = gitStatuses[url.path] ?? .clean
                        return item
                    }
                    
                    let sorted = Self.sortItems(items, field: sortField, order: sortOrder)
                    let imageCount = items.filter { $0.isImage }.count
                    let context: FolderContext = (Double(imageCount) / Double(max(1, items.count)) > 0.4) ? .assets : .standard
                    
                    return (sorted, context)
                }.value
                
                guard !Task.isCancelled else { return }

                await MainActor.run {
                    guard generation == self.loadGeneration else { return }
                    
                    for item in newItems {
                        if !previousItems.contains(item.url) {
                            self.recentArrivals[item.url] = Date()
                            Task {
                                try? await Task.sleep(nanoseconds: 5_000_000_000)
                                await MainActor.run {
                                    self.recentArrivals.removeValue(forKey: item.url)
                                }
                            }
                        }
                    }
                    
                    self.items = newItems
                    self.context = newContext
                    self.isPathLoading = false
                    self.loadTask = nil
                }
            } catch is CancellationError {
                await MainActor.run {
                    if generation == self.loadGeneration {
                        self.loadTask = nil
                    }
                }
            } catch {
                print("Error loading directory \(targetDirectory): \(error)")
                await MainActor.run {
                    guard generation == self.loadGeneration else { return }
                    self.items = []
                    self.isPathLoading = false
                    self.loadTask = nil
                }
            }
        }
    }

    private func getCachedGitStatus(for directory: URL) async -> [String: FileItem.GitStatus] {
        if let lastFetch = lastGitFetchTime[directory], Date().timeIntervalSince(lastFetch) < 2.0 {
            return gitStatusCache[directory] ?? [:]
        }
        
        let statuses = await fetchGitStatus(for: directory)
        gitStatusCache[directory] = statuses
        lastGitFetchTime[directory] = Date()
        return statuses
    }

    private func fetchGitStatus(for directory: URL) async -> [String: FileItem.GitStatus] {
        return await Task.detached(priority: .utility) {
            let process = Process()
            process.executableURL = URL(fileURLWithPath: "/usr/bin/git")
            process.arguments = ["status", "--porcelain"]
            process.currentDirectoryURL = directory
            
            let pipe = Pipe()
            process.standardOutput = pipe
            
            do {
                try process.run()
                let data = (try? pipe.fileHandleForReading.readDataToEndOfFile()) ?? Data()
                if let output = String(data: data, encoding: .utf8) {
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
            } catch {}
            return [:]
        }.value
    }

    func enterSoloMode() {
        guard let selectedID = selection.first,
              let treeItem = visibleItems.first(where: { $0.id == selectedID }),
              treeItem.item.isDirectory else { return }
        
        soloRoot = treeItem.item.url
        loadContents()
        selection = []
    }

    func exitSoloMode() {
        soloRoot = nil
        loadContents()
        selection = []
    }

    func refresh() {
        gitStatusCache.removeAll()
        lastGitFetchTime.removeAll()
        loadContents()
        refreshExpandedItems()
    }
    
    private func refreshExpandedItems() {
        for url in expandedItems {
            Task {
                let item = FileItem(url: url)
                let children = await loadChildrenAsync(for: item)
                await MainActor.run {
                    self.itemChildren[url] = children
                }
            }
        }
    }
    
    func toggleExpansion(for item: FileItem) {
        if expandedItems.contains(item.url) {
            expandedItems.remove(item.url)
        } else {
            expandedItems.insert(item.url)
            if itemChildren[item.url] == nil {
                Task {
                    let children = await loadChildrenAsync(for: item)
                    await MainActor.run {
                        self.itemChildren[item.url] = children
                    }
                }
            }
        }
    }
    
    func loadChildren(for item: FileItem) -> [FileItem] {
        loadChildrenSync(for: item)
    }

    private func loadChildrenSync(for item: FileItem) -> [FileItem] {
        guard item.isDirectory else { return [] }
        let keys: [URLResourceKey] = [.isDirectoryKey, .fileSizeKey, .contentModificationDateKey, .creationDateKey]
        let urls = (try? FileManager.default.contentsOfDirectory(at: item.url, includingPropertiesForKeys: keys, options: .skipsHiddenFiles)) ?? []
        return Self.sortItems(urls.map { FileItem(url: $0) }, field: sortField, order: sortOrder)
    }

    private func loadChildrenAsync(for item: FileItem) async -> [FileItem] {
        guard item.isDirectory else { return [] }
        let sortField = self.sortField
        let sortOrder = self.sortOrder
        let gitStatuses = await self.getCachedGitStatus(for: item.url)
        
        return await Task.detached(priority: .userInitiated) {
            let manager = FileManager.default
            let keys: [URLResourceKey] = [.isDirectoryKey, .fileSizeKey, .contentModificationDateKey, .creationDateKey]
            let urls = (try? manager.contentsOfDirectory(at: item.url, includingPropertiesForKeys: keys, options: .skipsHiddenFiles)) ?? []
            
            let items = urls.map { url in
                var item = FileItem(url: url)
                item.gitStatus = gitStatuses[url.path] ?? .clean
                return item
            }
            
            return Self.sortItems(items, field: sortField, order: sortOrder)
        }.value
    }

    private func sort(_ items: [FileItem]) -> [FileItem] {
        Self.sortItems(items, field: sortField, order: sortOrder)
    }

    nonisolated private static func sortItems(_ items: [FileItem], field: SortField, order: SortOrder) -> [FileItem] {
        items.sorted { a, b in
            if a.isDirectory != b.isDirectory {
                return a.isDirectory
            }

            let result: Bool
            switch field {
            case .name:
                result = a.name.localizedCompare(b.name) == .orderedAscending
            case .created:
                result = a.creationDate < b.creationDate
            case .modified:
                result = a.modificationDate < b.modificationDate
            }

            return order == .ascending ? result : !result
        }
    }
    
    private var _cachedVisibleItems: [VisibleTreeItem]?
    private var _lastVisibleItemsKey: String = ""

    var visibleItems: [VisibleTreeItem] {
        let key = "\(expandedItems.count)-\(items.count)-\(itemChildren.count)-\(sortField)-\(sortOrder)"
        if let cached = _cachedVisibleItems, key == _lastVisibleItemsKey {
            return cached
        }

        var result: [VisibleTreeItem] = []
        
        func addVisible(_ items: [FileItem], level: Int, parentLineStates: [Bool]) {
            for (index, item) in items.enumerated() {
                let isLast = index == items.count - 1
                result.append(VisibleTreeItem(
                    item: item,
                    level: level,
                    parentLineStates: parentLineStates,
                    isLast: isLast
                ))
                
                if expandedItems.contains(item.url), let children = itemChildren[item.url] {
                    let nextParentLineStates = parentLineStates + [!isLast]
                    addVisible(children, level: level + 1, parentLineStates: nextParentLineStates)
                }
            }
        }
        
        addVisible(items, level: 0, parentLineStates: [])
        _cachedVisibleItems = result
        _lastVisibleItemsKey = key
        return result
    }
    
    func selectNext() {
        let visible = visibleItems
        guard !visible.isEmpty else { return }
        if let selectedID = selection.first,
           let currentIndex = visible.firstIndex(where: { $0.id == selectedID }) {
            let nextIndex = min(currentIndex + 1, visible.count - 1)
            selection = [visible[nextIndex].id]
        } else {
            selection = [visible[0].id]
        }
    }
    
    func selectPrevious() {
        let visible = visibleItems
        guard !visible.isEmpty else { return }
        if let selectedID = selection.first,
           let currentIndex = visible.firstIndex(where: { $0.id == selectedID }) {
            let prevIndex = max(currentIndex - 1, 0)
            selection = [visible[prevIndex].id]
        } else {
            selection = [visible[0].id]
        }
    }
    
    func handleRightArrow() {
        guard let selectedID = selection.first,
              let treeItem = visibleItems.first(where: { $0.id == selectedID }) else { return }
        
        let item = treeItem.item
        if item.isDirectory {
            if !expandedItems.contains(item.url) {
                toggleExpansion(for: item)
            } else {
                if let children = itemChildren[item.url], !children.isEmpty {
                    selection = [children[0].url]
                }
            }
        }
    }
    
    func handleLeftArrow() {
        guard let selectedID = selection.first else { return }
        let visible = visibleItems
        guard let currentIndex = visible.firstIndex(where: { $0.id == selectedID }) else { return }
        
        let treeItem = visible[currentIndex]
        let item = treeItem.item
        
        if item.isDirectory && expandedItems.contains(item.url) {
            toggleExpansion(for: item)
        } else {
            for i in (0..<currentIndex).reversed() {
                let potentialParent = visible[i]
                if let children = itemChildren[potentialParent.id],
                   children.contains(where: { $0.url == selectedID }) {
                    selection = [potentialParent.id]
                    return
                }
            }
            navigateOut()
        }
    }
    
    func handleSpacebar() {
        guard let selectedID = selection.first,
              let treeItem = visibleItems.first(where: { $0.id == selectedID }),
              !treeItem.item.isDirectory else {
            previewURL = nil
            return
        }
        
        let item = treeItem.item
        if previewURL == item.url {
            previewURL = nil
        } else {
            previewURL = item.url
        }
    }

    func activate(_ item: FileItem) {
        selection = [item.url]
        if item.isDirectory {
            toggleExpansion(for: item)
        } else {
            smartOpen(item.url)
        }
    }
    
    private func smartOpen(_ url: URL) {
        let textExtensions = ["txt", "md", "json", "swift", "js", "ts", "html", "css", "py", "sh", "yml", "yaml"]
        if textExtensions.contains(url.pathExtension.lowercased()) {
            mode = .editor(url)
        } else {
            NSWorkspace.shared.open(url)
        }
    }

    func openWith(_ url: URL, appURL: URL? = nil) {
        if let appURL = appURL {
            NSWorkspace.shared.open([url], withApplicationAt: appURL, configuration: NSWorkspace.OpenConfiguration())
        } else {
            NSWorkspace.shared.open(url)
        }
    }
    
    private func updateDirectory(_ newURL: URL, clearForward: Bool = true) {
        guard newURL != currentDirectory else { return }
        if clearForward {
            backStack.append(currentDirectory)
            forwardStack.removeAll()
        }
        currentDirectory = newURL
        selection = []
    }
    
    func navigateIn() {
        guard let selectedID = selection.first,
              let treeItem = visibleItems.first(where: { $0.id == selectedID }) else { return }
        let item = treeItem.item
        if item.isDirectory {
            updateDirectory(item.url)
        } else {
            smartOpen(item.url)
        }
    }

    func closeEditor() {
        mode = .browser
    }

    func navigateOut() {
        let parent = currentDirectory.deletingLastPathComponent()
        guard parent.path != currentDirectory.path else { return }
        updateDirectory(parent)
    }
    
    func navigateBack() {
        guard let previous = backStack.popLast() else { return }
        forwardStack.append(currentDirectory)
        updateDirectory(previous, clearForward: false)
    }
    
    func navigateForward() {
        guard let next = forwardStack.popLast() else { return }
        backStack.append(currentDirectory)
        updateDirectory(next, clearForward: false)
    }

    func createNewFolder() {
        let baseUrl = currentDirectory
        var folderName = "untitled folder"
        var folderUrl = baseUrl.appendingPathComponent(folderName)
        var count = 2
        while FileManager.default.fileExists(atPath: folderUrl.path) {
            folderName = "untitled folder \(count)"
            folderUrl = baseUrl.appendingPathComponent(folderName)
            count += 1
        }
        do {
            try FileManager.default.createDirectory(at: folderUrl, withIntermediateDirectories: true)
            loadContents()
            if let newItem = items.first(where: { $0.url.path == folderUrl.path }) {
                selection = [newItem.url]
            }
        } catch {
            print("Error creating folder: \(error)")
        }
    }

    func renameSelected(to newName: String) {
        guard let selectedID = selection.first,
              let treeItem = visibleItems.first(where: { $0.id == selectedID }) else { return }
        let item = treeItem.item
        let newURL = item.url.deletingLastPathComponent().appendingPathComponent(newName)
        do {
            try FileManager.default.moveItem(at: item.url, to: newURL)
            loadContents()
            if let newItem = items.first(where: { $0.url.path == newURL.path }) {
                selection = [newItem.url]
            }
        } catch {
            print("Error renaming item: \(error)")
        }
    }

    func moveItem(at sourceURL: URL, to destinationDirectory: URL) {
        let destinationURL = destinationDirectory.appendingPathComponent(sourceURL.lastPathComponent)
        guard sourceURL.path != destinationURL.path else { return }
        do {
            try FileManager.default.moveItem(at: sourceURL, to: destinationURL)
            SoundManager.shared.play(.teleport)
            NotificationCenter.default.post(name: Self.shouldRefreshPanes, object: nil)
        } catch {
            SoundManager.shared.play(.error)
            print("Error moving item: \(error)")
        }
    }

    func moveSelectionToTrash() {
        let selectedItems = visibleItems.filter { selection.contains($0.id) }.map { $0.item }
        guard !selectedItems.isEmpty else { return }
        let urls = selectedItems.map { $0.url }
        NSWorkspace.shared.recycle(urls) { (newURLs, error) in
            DispatchQueue.main.async {
                if let error = error {
                    SoundManager.shared.play(.error)
                    print("Error moving to trash: \(error)")
                } else {
                    SoundManager.shared.play(.teleport)
                }
                NotificationCenter.default.post(name: Self.shouldRefreshPanes, object: nil)
                self.selection = []
            }
        }
    }

    func copySelectionToClipboardRich() {
        let selectedItems = visibleItems.filter { selection.contains($0.id) }.map { $0.item }
        guard !selectedItems.isEmpty else { return }
        
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        
        let urls = selectedItems.map { $0.url as NSURL }
        pasteboard.writeObjects(urls)
        
        for item in selectedItems where item.isImage {
            if let image = NSImage(contentsOf: item.url) {
                pasteboard.setData(image.tiffRepresentation, forType: .tiff)
            }
        }
        
        SoundManager.shared.play(.teleport)
    }

    struct ScoredResult: Comparable {
        let item: FileItem
        let score: Double
        static func < (lhs: ScoredResult, rhs: ScoredResult) -> Bool {
            lhs.score > rhs.score
        }
    }

    func searchFiles(query: String) async -> [FileItem] {
        guard !query.isEmpty else { return [] }
        
        let rootURL = currentDirectory
        let now = Date()
        
        return await Task.detached(priority: .userInitiated) {
            let manager = FileManager.default
            var scoredResults: [ScoredResult] = []
            let options: FileManager.DirectoryEnumerationOptions = [.skipsHiddenFiles, .skipsPackageDescendants]
            
            guard let enumerator = manager.enumerator(at: rootURL,
                                                   includingPropertiesForKeys: [.isDirectoryKey, .fileSizeKey, .contentModificationDateKey, .creationDateKey],
                                                   options: options) else {
                return []
            }
            
            while let url = enumerator.nextObject() as? URL {
                let name = url.lastPathComponent
                if name.localizedCaseInsensitiveContains(query) {
                    let item = FileItem(url: url)
                    
                    var nameScore = 0.0
                    if name.localizedCaseInsensitiveCompare(query) == .orderedSame {
                        nameScore = 1.0
                    } else if name.lowercased().hasPrefix(query.lowercased()) {
                        nameScore = 0.8
                    } else {
                        nameScore = 0.5
                    }
                    
                    let interval = now.timeIntervalSince(item.modificationDate)
                    var recencyScore = 0.0
                    if interval < 3600 { recencyScore = 1.0 }
                    else if interval < 86400 { recencyScore = 0.5 }
                    else if interval < 604800 { recencyScore = 0.2 }
                    
                    scoredResults.append(ScoredResult(item: item, score: nameScore + recencyScore))
                }
                if scoredResults.count >= 100 { break }
                if Task.isCancelled { return [] }
            }
            
            return scoredResults.sorted().prefix(20).map { $0.item }
        }.value
    }

    func revealAndSelect(item: FileItem) {
        var current = item.url.deletingLastPathComponent()
        var parentsToExpand: [URL] = []
        while current.path.hasPrefix(currentDirectory.path) && current.path != currentDirectory.path {
            parentsToExpand.append(current)
            current = current.deletingLastPathComponent()
        }
        for parentURL in parentsToExpand.reversed() {
            if !expandedItems.contains(parentURL) {
                expandedItems.insert(parentURL)
                self.itemChildren[parentURL] = loadChildrenSync(for: FileItem(url: parentURL))
            }
        }
        selection = [item.url]
    }
}
