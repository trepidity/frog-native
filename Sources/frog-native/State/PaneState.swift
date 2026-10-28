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
    private let preferences: UserDefaults
    @Published private var columnSelection: Set<FileColumn>?
    var displayedColumns: [FileColumn] {
        let defaults: Set<FileColumn>
        if currentLayout == .verticalTree {
            defaults = context == .assets ? [.name, .dimensions, .kind, .size] : [.name, .created, .modified, .size]
        } else {
            defaults = [.name, .modified, .size]
        }
        let selected = columnSelection ?? defaults
        return FileColumn.allCases.filter { $0 == .name || selected.contains($0) }
    }

    func setColumnVisible(_ column: FileColumn, _ visible: Bool) {
        guard column != .name else { return }
        var columns = Set(displayedColumns)
        if visible { columns.insert(column) } else { columns.remove(column) }
        setVisibleColumns(columns)
    }

    func setVisibleColumns(_ columns: Set<FileColumn>) {
        let selected = columns.union([.name])
        guard selected != columnSelection else { return }
        columnSelection = selected
        preferences.set(FileColumn.allCases.filter { selected.contains($0) }.map(\.rawValue), forKey: "pane.\(id).columns")
    }

    func resetColumns() {
        columnSelection = nil
        preferences.removeObject(forKey: "pane.\(id).columns")
    }
    @Published var currentLayout: LayoutType = .verticalTree {
        didSet { preferences.set(currentLayout.rawValue, forKey: "pane.\(id).layout") }
    }
    @Published var currentDirectory: URL
    @Published var mode: PaneMode = .browser
    @Published var items: [FileItem] = [] {
        didSet { cachedVisibleItems = nil }
    }
    @Published var selection: Set<URL> = []
    @Published private(set) var showHiddenFiles = true
    var displayedItems: [FileItem] { showHiddenFiles ? items : items.filter { !$0.isHidden } }

    func setHiddenFilesVisible(_ visible: Bool) {
        showHiddenFiles = visible
        preferences.set(visible, forKey: "pane.\(id).showHiddenFiles")
        if !visible {
            selection.formIntersection(Set(visibleItems.map(\.id)))
        }
    }

    @Published var expandedItems: Set<URL> = []
    @Published var itemChildren: [URL: [FileItem]] = [:] {
        didSet { cachedVisibleItems = nil }
    }

    @Published var sortField: SortField = .name
    @Published var sortOrder: SortOrder = .ascending

    @Published var backStack: [URL] = []
    @Published var forwardStack: [URL] = []

    @Published var previewURL: URL?
    @Published var renameTarget: FileItem?
    @Published var soloRoot: URL? {
        didSet {
            guard oldValue?.canonicalDirectoryURL.path != soloRoot?.canonicalDirectoryURL.path else { return }
            startDirectoryMonitor()
        }
    }
    @Published var isPathLoading: Bool = false

    @Published var context: FolderContext = .standard
    @Published var recentArrivals: [URL: Date] = [:]

    enum FolderContext {
        case standard
        case assets
    }

    var cancellables = Set<AnyCancellable>()
    var loadTask: Task<Void, Never>?
    var loadGeneration: Int = 0
    var pendingReveal: URL?

    var gitStatusCache: [URL: [String: FileItem.GitStatus]] = [:]
    var lastGitFetchTime: [URL: Date] = [:]

    var cachedVisibleItems: [VisibleTreeItem]?
    var lastVisibleItemsKey: String = ""
    var directoryMonitor: DirectoryChangeMonitor?
    var directoryMonitorGeneration = 0
    var monitoredRoot: String?
    var pendingDirectoryEvents: [String] = []
    var pendingDirectoryRescan = false
    var directoryRefreshTask: Task<Void, Never>?

    static let shouldRefreshPanes = Notification.Name("shouldRefreshPanes")

    init(id: String, directory: URL, preferences: UserDefaults = .standard) {
        self.id = id
        self.preferences = preferences
        if let columns = preferences.stringArray(forKey: "pane.\(id).columns") {
            self.columnSelection = Set(columns.compactMap(FileColumn.init(rawValue:))).union([.name])
        }
        let layout = preferences.string(forKey: "pane.\(id).layout") ?? preferences.string(forKey: "browser.currentLayout")
        self.currentLayout = layout.flatMap(LayoutType.init(rawValue:)) ?? .verticalTree
        self.showHiddenFiles = preferences.object(forKey: "pane.\(id).showHiddenFiles") as? Bool
            ?? preferences.object(forKey: "browser.showHiddenFiles") as? Bool ?? true

        if let savedPath = UserDefaults.standard.string(forKey: "pane.\(id).currentDirectory"),
           FileManager.default.fileExists(atPath: savedPath) {
            self.currentDirectory = URL(fileURLWithPath: savedPath)
        } else {
            self.currentDirectory = directory
        }

        // Snapshot legacy shared values once; later changes belong only to this pane.
        preferences.set(currentLayout.rawValue, forKey: "pane.\(id).layout")
        preferences.set(showHiddenFiles, forKey: "pane.\(id).showHiddenFiles")

        if let savedExpanded = UserDefaults.standard.stringArray(forKey: "pane.\(id).expandedItems") {
            self.expandedItems = Set(savedExpanded.map { URL(fileURLWithPath: $0) })
        }

        loadContents()
        wireSubscriptions()
        // Restore children asynchronously so large saved folders cannot block launch.
        refreshExpandedItems()
        startDirectoryMonitor()
    }

    private func wireSubscriptions() {
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
                self.startDirectoryMonitor()
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
}
