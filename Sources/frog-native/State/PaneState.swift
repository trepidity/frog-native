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

    @Published var previewURL: URL?
    @Published var soloRoot: URL?
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

    var gitStatusCache: [URL: [String: FileItem.GitStatus]] = [:]
    var lastGitFetchTime: [URL: Date] = [:]

    var cachedVisibleItems: [VisibleTreeItem]?
    var lastVisibleItemsKey: String = ""

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
        wireSubscriptions()
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
