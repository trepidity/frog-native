import SwiftUI

struct CommandPaletteView: View {
    @Environment(\.fileManagerPalette)
    private var theme
    @ObservedObject var state: BrowserState
    @State private var searchText: String = ""
    @State private var selectedIndex: Int = 0
    @StateObject private var search = UniversalSearchSession()
    @ObservedObject private var index = UniversalSearchIndex.shared
    @State private var navigationError: String?
    @State private var navigationTask: Task<Void, Never>?
    @State private var navigationGeneration = 0
    @State private var previewURL: URL?
    @State private var previewTask: Task<Void, Never>?
    @FocusState private var isTextFieldFocused: Bool
    var actions: [CommandAction] {
        var baseActions = [
            CommandAction(title: "Focus Left Pane", icon: "arrow.left.square") {
                state.focusedPane = .left
            },
            CommandAction(title: "Focus Right Pane", icon: "arrow.right.square") {
                state.focusedPane = .right
            },
            CommandAction(title: "New Folder", icon: "folder.badge.plus") {
                state.activePane.createNewFolder()
            },
            CommandAction(title: "Move to Trash", icon: "trash") {
                state.activePane.confirmMoveSelectionToTrash()
            },
            CommandAction(title: "Open User Guide", icon: "book") {
                state.activePane.mode = .helpGuide
            },
            CommandAction(title: "Teleport: Sync Paths", icon: "arrow.left.and.right.righttriangle.left.righttriangle.right") {
                state.teleportSyncPath()
            },
            CommandAction(title: "Teleport: Copy Selection", icon: "paperplane") {
                state.teleportCopySelection()
            }
        ]

        // Add layout switching actions
        for layout in LayoutType.allCases {
            baseActions.append(CommandAction(title: "Active Pane: \(layout.rawValue) Layout", icon: "square.grid.2x2") {
                state.activePane.currentLayout = layout
            })
        }

        return baseActions
    }

    var combinedResults: [SearchResult] {
        var results: [SearchResult] = []

        // Actions
        let filteredActions = actions.filter { searchText.isEmpty || $0.title.localizedCaseInsensitiveContains(searchText) }

        // Files
        if !searchText.isEmpty {
            results.append(contentsOf: search.results.map { .file($0) })
        }

        results.append(contentsOf: filteredActions.map { .action($0) })
        return results
    }

    var body: some View {
        VStack(spacing: 0) {
            // Search Bar
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(theme.ink.secondary)
                TextField("", text: $searchText, prompt: Text("Search this Mac, enter a path, or type a command…").foregroundColor(theme.ink.muted))
                    .textFieldStyle(.plain)
                    .foregroundStyle(theme.ink.primary)
                    .focused($isTextFieldFocused)
                    .onChange(of: searchText) { _, _ in
                        selectedIndex = 0
                        scheduleSearch()
                    }
                    .onSubmit {
                        executeSelectedAction(openDirectly: NSEvent.modifierFlags.contains(.command))
                    }
            }
            .padding(16)
            .background(theme.bg2)

            ThemeDivider()

            // Keep every search state inside the same content area.
            VStack(spacing: 0) {
                Group {
                    if !combinedResults.isEmpty {
                        ScrollViewReader { proxy in
                            List(0..<combinedResults.count, id: \.self) { index in
                                resultRow(for: combinedResults[index], at: index)
                                    .id(index)
                                    .listRowBackground(theme.panel)
                                    .listRowSeparator(.hidden)
                            }
                            .listStyle(.plain)
                            .scrollContentBackground(.hidden)
                            .background(theme.panel)
                            .onChange(of: selectedIndex) { _, newIndex in
                                schedulePreview(for: newIndex)
                                proxy.scrollTo(newIndex)
                            }
                        }
                    } else {
                        noResultsView
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)

                if let message = navigationError ?? search.errorMessage {
                    Text(message)
                        .font(.caption)
                        .foregroundColor(theme.ink.secondary)
                        .padding(8)
                }
            }
            .frame(height: 400)

            ThemeDivider()

            // Footer Hints
            HStack {
                Text("⏎ Jump")
                Text("⌘⏎ Open File").padding(.leading, 8)
                Spacer()
                Text(search.isSearching ? "Searching…" : index.status).lineLimit(1)
            }
            .font(.system(size: 9, weight: .medium))
            .foregroundColor(theme.ink.secondary)
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(theme.bg2)
        }
        .frame(width: 550, height: 478)
        .background(theme.panel)
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(theme.rule2, lineWidth: 1)
        )
        .shadow(radius: 20)
        .onAppear {
            scheduleSearch()
        }
        .task {
            await Task.yield()
            isTextFieldFocused = true
        }
        .defaultFocus($isTextFieldFocused, true)
        .onDisappear {
            search.cancel()
            navigationTask?.cancel()
            navigationGeneration += 1
            previewTask?.cancel()
            previewURL = nil
        }
        .onKeyPress(.downArrow) {
            selectedIndex = max(0, min(selectedIndex + 1, combinedResults.count - 1))
            return .handled
        }
        .onKeyPress(.upArrow) {
            selectedIndex = max(selectedIndex - 1, 0)
            return .handled
        }
        .onKeyPress(.escape) {
            state.isCommandPalettePresented = false
            return .handled
        }
        .onChange(of: index.revision) { _, _ in search.refresh(index: index.index) }
        .onChange(of: search.results) { old, new in
            // Keep a keyboard-selected file selected when another provider publishes.
            if selectedIndex > 0, old.indices.contains(selectedIndex),
               let position = new.firstIndex(where: { $0.id == old[selectedIndex].id }) {
                selectedIndex = position
            } else {
                selectedIndex = min(selectedIndex, max(0, combinedResults.count - 1))
            }
            previewTask?.cancel()
            previewURL = nil
        }
        .auraQuickLookPreview($previewURL)
    }

    @ViewBuilder
    private func resultRow(for result: SearchResult, at index: Int) -> some View {
        HStack {
            Image(systemName: result.icon)
                .frame(width: 20)
                .foregroundColor(result.isAction ? theme.ink.primary : (result.isDirectory ? theme.ink.blue : theme.ink.secondary))

            VStack(alignment: .leading, spacing: 2) {
                Text(result.title)
                    .fontWeight(selectedIndex == index ? .bold : .regular)

                if case .file(let item) = result {
                    Text(item.url.path.replacingOccurrences(of: FileManager.default.homeDirectoryForCurrentUser.path, with: "~"))
                        .font(.system(size: 10, design: .monospaced))
                        .foregroundColor(theme.ink.secondary)
                        .lineLimit(1)
                }
            }

            Spacer()

            if result.isAction {
                Text("Action")
                    .font(.system(size: 9, weight: .bold))
                    .padding(.horizontal, 4)
                    .padding(.vertical, 2)
                    .background(theme.bg2)
                    .cornerRadius(4)
            }
        }
        .padding(.vertical, 4)
        .padding(.horizontal, 8)
        .background(SelectionBackground(selected: selectedIndex == index))
        .foregroundColor(theme.ink.primary)
        .cornerRadius(4)
        .onTapGesture {
            selectedIndex = index
            executeSelectedAction(openDirectly: false)
        }
        .onHover { hovering in
            if hovering {
                selectedIndex = index
            }
        }
    }

    private var noResultsView: some View {
        VStack(spacing: 12) {
            Image(systemName: "sparkles")
                .font(.largeTitle)
                .foregroundColor(theme.ink.secondary)
            Text(search.isSearching || index.isIndexing ? "Searching this Mac…" : "No matching files or folders")
                .foregroundColor(theme.ink.secondary)
        }
        .padding(40)
    }

    private func executeSelectedAction(openDirectly: Bool) {
        guard combinedResults.indices.contains(selectedIndex) else { return }
        let selected = combinedResults[selectedIndex]

        switch selected {
        case .action(let action):
            action.action()
        case .file(let item):
            navigationTask?.cancel()
            navigationGeneration += 1
            let version = navigationGeneration
            let targetPane = state.activePane
            let originalDirectory = targetPane.currentDirectory
            navigationTask = Task {
                let work = Task.detached(priority: .userInitiated) { () -> (entry: SearchEntry, hidden: Bool)? in
                    guard !Task.isCancelled else { return nil }
                    var directory: ObjCBool = false
                    guard FileManager.default.fileExists(atPath: item.url.path, isDirectory: &directory) else { return nil }
                    let hidden = item.url.lastPathComponent.hasPrefix(".") ||
                        ((try? item.url.resourceValues(forKeys: [.isHiddenKey]).isHidden) == true)
                    return (SearchEntry(url: item.url, isDirectory: directory.boolValue), hidden)
                }
                let resolved = await withTaskCancellationHandler { await work.value } onCancel: { work.cancel() }
                guard !Task.isCancelled, version == navigationGeneration, state.isCommandPalettePresented,
                      targetPane === state.activePane, targetPane.currentDirectory == originalDirectory else { return }
                guard let resolved else {
                    navigationError = "This item has moved, was deleted, or is not accessible."
                    return
                }
                if openDirectly && !resolved.entry.isDirectory {
                    targetPane.smartOpen(resolved.entry.url)
                } else {
                    // An explicit search reveal must not select an invisible row.
                    if resolved.hidden && !resolved.entry.isDirectory { targetPane.setHiddenFilesVisible(true) }
                    targetPane.jump(to: resolved.entry)
                }
                state.isCommandPalettePresented = false
                NotificationCenter.default.post(name: NSNotification.Name("reclaimAuraFocus"), object: nil)
            }
            return
        }

        state.isCommandPalettePresented = false
    }

    private func schedulePreview(for index: Int) {
        previewTask?.cancel()

        previewTask = Task {
            try? await Task.sleep(nanoseconds: 600_000_000) // 600ms delay
            guard !Task.isCancelled else { return }

            await MainActor.run {
                updatePreview(for: index)
            }
        }
    }

    private func updatePreview(for index: Int) {
        guard combinedResults.indices.contains(index) else {
            previewURL = nil
            return
        }

        if case .file(let item) = combinedResults[index] {
            previewURL = item.url
        } else {
            previewURL = nil
        }
    }

    private func scheduleSearch() {
        navigationTask?.cancel()
        navigationGeneration += 1
        navigationError = nil
        previewTask?.cancel()
        previewURL = nil
        search.search(searchText, index: index.index)
    }
}

extension CommandPaletteView {
    enum SearchResult: Identifiable, Equatable {
        case action(CommandAction)
        case file(SearchEntry)

        static func == (lhs: SearchResult, rhs: SearchResult) -> Bool {
            lhs.id == rhs.id
        }

        var id: String {
            switch self {
            case .action(let action): return "action-\(action.title)"
            case .file(let item): return "file-\(item.url.path)"
            }
        }

        var title: String {
            switch self {
            case .action(let action): return action.title
            case .file(let item): return item.name
            }
        }

        var icon: String {
            switch self {
            case .action(let action): return action.icon
            case .file(let item): return item.isDirectory ? "folder.fill" : "doc.fill"
            }
        }

        var isAction: Bool {
            if case .action = self { return true }
            return false
        }

        var isDirectory: Bool {
            if case .file(let item) = self { return item.isDirectory }
            return false
        }
    }
}
