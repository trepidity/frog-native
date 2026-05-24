import SwiftUI

struct CommandPaletteView: View {
    @ObservedObject var state: BrowserState
    @State private var searchText: String = ""
    @State private var selectedIndex: Int = 0
    @State private var fileResults: [FileItem] = []
    @State private var searchTask: Task<Void, Never>?
    @State private var previewURL: URL?
    @State private var previewTask: Task<Void, Never>?
    @FocusState private var isTextFieldFocused: Bool
    
    enum SearchResult: Identifiable, Equatable {
        case action(CommandAction)
        case file(FileItem)
        
        static func == (lhs: SearchResult, rhs: SearchResult) -> Bool {
            lhs.id == rhs.id
        }
        
        var id: String {
            switch self {
            case .action(let action): return "action-\(action.title)"
            case .file(let item): return "file-\(item.id.path)"
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
            CommandAction(title: "Toggle Hidden Files", icon: "eye.slash") {
                // Placeholder
                print("Toggle Hidden Files action")
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
            baseActions.append(CommandAction(title: "Switch to \(layout.rawValue) Layout", icon: "square.grid.2x2") {
                state.currentLayout = layout
            })
        }
        
        return baseActions
    }
    
    var combinedResults: [SearchResult] {
        var results: [SearchResult] = []
        
        // Actions
        let filteredActions = actions.filter { searchText.isEmpty || $0.title.localizedCaseInsensitiveContains(searchText) }
        results.append(contentsOf: filteredActions.map { .action($0) })
        
        // Files
        if !searchText.isEmpty {
            results.append(contentsOf: fileResults.map { .file($0) })
        }
        
        return results
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Search Bar
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.secondary)
                TextField("Type a command or search files...", text: $searchText)
                    .textFieldStyle(.plain)
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
            
            Divider()
            
            // Results List
            Group {
                if !combinedResults.isEmpty {
                    List(0..<combinedResults.count, id: \.self) { index in
                        resultRow(for: combinedResults[index], at: index)
                    }
                    .listStyle(.plain)
                    .frame(maxHeight: 400)
                    .onChange(of: selectedIndex) { _, newIndex in
                        schedulePreview(for: newIndex)
                    }
                } else {
                    noResultsView
                }
            }
            
            Divider()
            
            // Footer Hints
            HStack {
                Text("⏎ Jump to Tree")
                Text("⌘⏎ Open File").padding(.leading, 8)
                Spacer()
                Text("Aura Spotlight").italic().opacity(0.5)
            }
            .font(.system(size: 9, weight: .medium))
            .foregroundColor(.secondary)
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(Color.primary.opacity(0.03))
        }
        .frame(width: 550)
        .background(VisualEffectView(material: .popover, blendingMode: .withinWindow))
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.primary.opacity(0.1), lineWidth: 1)
        )
        .shadow(radius: 20)
        .onAppear {
            isTextFieldFocused = true
            scheduleSearch()
        }
        .onDisappear {
            searchTask?.cancel()
            previewTask?.cancel()
            previewURL = nil
        }
        .onKeyPress(.downArrow) {
            selectedIndex = min(selectedIndex + 1, combinedResults.count - 1)
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
        .auraQuickLookPreview($previewURL)
    }
    
    @ViewBuilder
    private func resultRow(for result: SearchResult, at index: Int) -> some View {
        HStack {
            Image(systemName: result.icon)
                .frame(width: 20)
                .foregroundColor(result.isAction ? .primary : (result.isDirectory ? .blue : .secondary))
            
            VStack(alignment: .leading, spacing: 2) {
                Text(result.title)
                    .fontWeight(selectedIndex == index ? .bold : .regular)
                
                if case .file(let item) = result {
                    Text(item.url.path.replacingOccurrences(of: FileManager.default.homeDirectoryForCurrentUser.path, with: "~"))
                        .font(.system(size: 10, design: .monospaced))
                        .foregroundColor(selectedIndex == index ? .white.opacity(0.8) : .secondary)
                        .lineLimit(1)
                }
            }
            
            Spacer()
            
            if result.isAction {
                Text("Action")
                    .font(.system(size: 9, weight: .bold))
                    .padding(.horizontal, 4)
                    .padding(.vertical, 2)
                    .background(Color.primary.opacity(0.1))
                    .cornerRadius(4)
            }
        }
        .padding(.vertical, 4)
        .padding(.horizontal, 8)
        .background(selectedIndex == index ? Color.accentColor : Color.clear)
        .foregroundColor(selectedIndex == index ? .white : .primary)
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
                .foregroundColor(.secondary)
            Text(searchText.isEmpty ? "Search for commands or files..." : "No matching results in Aura Spotlight")
                .foregroundColor(.secondary)
        }
        .padding(40)
    }

    private func executeSelectedAction(openDirectly: Bool) {
        guard selectedIndex < combinedResults.count else { return }
        let selected = combinedResults[selectedIndex]
        
        switch selected {
        case .action(let action):
            action.action()
        case .file(let item):
            if openDirectly {
                state.activePane.activate(item)
            } else {
                state.activePane.revealAndSelect(item: item)
                // Signal DualPaneView to take focus back
                NotificationCenter.default.post(name: NSNotification.Name("reclaimAuraFocus"), object: nil)
            }
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
        guard index < combinedResults.count else {
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
        searchTask?.cancel()

        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else {
            fileResults = []
            return
        }

        let activePane = state.activePane
        searchTask = Task {
            try? await Task.sleep(nanoseconds: 150_000_000)
            guard !Task.isCancelled else { return }

            let results = await activePane.searchFiles(query: query)
            guard !Task.isCancelled else { return }

            await MainActor.run {
                guard self.searchText.trimmingCharacters(in: .whitespacesAndNewlines) == query else { return }
                self.fileResults = results
            }
        }
    }
}
