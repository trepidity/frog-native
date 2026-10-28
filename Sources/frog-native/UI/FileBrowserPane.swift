import SwiftUI
import _QuickLook_SwiftUI

struct FileBrowserPane: View {
    @Environment(\.fileManagerPalette)
    private var theme
    @ObservedObject var paneState: PaneState
    let isFocused: Bool
    let acceptsPointerActivation: Bool
    let activate: () -> Void
    private var layout: LayoutType { paneState.currentLayout }
    
    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 6) {
                AuraPathHeader(paneState: paneState)
                    .frame(maxWidth: .infinity)
                    .clipped()
                Menu {
                    ForEach(LayoutType.allCases, id: \.self) { choice in
                        Button {
                            activate()
                            paneState.currentLayout = choice
                        } label: {
                            if choice == layout { Label(choice.rawValue, systemImage: "checkmark") } else { Text(choice.rawValue) }
                        }
                    }
                } label: {
                    Image(systemName: "rectangle.split.3x1")
                }
                .menuStyle(.borderlessButton)
                .fixedSize()
                .help("Layout for this pane: \(layout.rawValue)")
                .accessibilityLabel("\(paneState.id.capitalized) pane layout: \(layout.rawValue)")
                Button {
                    activate()
                    paneState.setHiddenFilesVisible(!paneState.showHiddenFiles)
                } label: {
                    Image(systemName: paneState.showHiddenFiles ? "eye" : "eye.slash")
                }
                .buttonStyle(.plain)
                .help("\(paneState.showHiddenFiles ? "Hide" : "Show") hidden files in this pane (⌘⇧.)")
                .accessibilityLabel("\(paneState.id.capitalized) pane hidden files: \(paneState.showHiddenFiles ? "on" : "off")")
            }
            .padding(.trailing, 10)
            .frame(height: 28)
            .background(theme.bg2)
            .overlay(ThemeDivider(), alignment: .bottom)
            switch paneState.mode {
            case .browser:
                browserView
                    .transition(.asymmetric(insertion: .move(edge: .leading), removal: .move(edge: .leading)))
            case .editor(let url):
                AuraEditorView(url: url, paneState: paneState)
                    .transition(.asymmetric(insertion: .move(edge: .trailing), removal: .move(edge: .trailing)))
            case .helpGuide:
                HelpGuideView(paneState: paneState)
                    .transition(.asymmetric(insertion: .move(edge: .bottom), removal: .move(edge: .bottom)))
            }
        }
        .background(theme.background)
        .background(PaneActivationObserver(isEnabled: acceptsPointerActivation, activate: activate))
        .overlay(
            RoundedRectangle(cornerRadius: 0)
                .stroke(isFocused ? theme.ink.blue : theme.rule, lineWidth: isFocused ? 2 : 1)
                .allowsHitTesting(false)
        )
        .contextMenu { FileBrowserContextMenu(paneState: paneState, targetIDs: paneState.selection) }
        .sheet(item: $paneState.renameTarget) { item in
            RenameItemSheet(paneState: paneState, item: item)
        }
        .auraQuickLookPreview($paneState.previewURL)
    }

    private var columnCustomization: Binding<TableColumnCustomization<FileItem>> {
        Binding(get: {
            var customization = TableColumnCustomization<FileItem>()
            for column in FileColumn.allCases {
                customization[visibility: column.rawValue] = paneState.displayedColumns.contains(column) ? .visible : .hidden
            }
            return customization
        }, set: { customization in
            let columns = FileColumn.allCases.filter { customization[visibility: $0.rawValue] != .hidden }
            paneState.setVisibleColumns(Set(columns))
        })
    }

    @ViewBuilder private var browserView: some View {
        VStack(spacing: 0) {
            // Content Body
            if layout == .classic {
                List(paneState.displayedItems, selection: $paneState.selection) { item in
                    HStack {
                        Image(systemName: item.isDirectory ? "folder.fill" : "doc.fill")
                            .foregroundColor(paneState.selection.contains(item.url) ? .primary : theme.ink.kind(for: item))
                        Text(item.name).foregroundColor(paneState.selection.contains(item.url) ? .primary : theme.ink.name(for: item))
                    }
                    .itemProvider {
                        NSItemProvider(object: item.url as NSURL)
                    }
                }
                .listStyle(.inset)
                .contextMenu(forSelectionType: URL.self) { targets in
                    FileBrowserContextMenu(paneState: paneState, targetIDs: targets)
                }
                .scrollContentBackground(.hidden)
                .alternatingRowBackgrounds(.disabled)
                .background(theme.background)
                .onDrop(of: [.fileURL], isTargeted: nil) { providers in
                    handleDrop(providers: providers, targetURL: paneState.currentDirectory, paneState: paneState)
                    return true
                }
            } else if layout == .verticalTree {
                VerticalTreePane(paneState: paneState, isFocused: isFocused)
            } else {
                // Table view for Pro and Staircase
                Table(paneState.displayedItems, selection: $paneState.selection, columnCustomization: columnCustomization) {
                    TableColumn("Name") { item in
                        HStack {
                            Image(systemName: item.isDirectory ? "folder.fill" : "doc.fill")
                                .foregroundColor(paneState.selection.contains(item.url) ? .primary : theme.ink.kind(for: item))
                                .frame(width: 16)
                            Text(item.name).foregroundColor(paneState.selection.contains(item.url) ? .primary : theme.ink.name(for: item))
                        }
                    }

                    .customizationID(FileColumn.name.rawValue)
                    .disabledCustomizationBehavior([.visibility, .reorder])

                    TableColumn("Created") { item in
                        FileMetadataCell(column: .created, item: item)
                            .foregroundColor(paneState.selection.contains(item.url) ? .primary : theme.ink.secondary)
                    }
                    .width(min: 80, ideal: 120, max: 160)
                    .customizationID(FileColumn.created.rawValue)
                    .disabledCustomizationBehavior(.reorder)

                    TableColumn("Modified") { item in
                        FileMetadataCell(column: .modified, item: item)
                            .foregroundColor(paneState.selection.contains(item.url) ? .primary : theme.ink.secondary)
                    }
                    .width(min: 80, ideal: 120, max: 160)
                    .customizationID(FileColumn.modified.rawValue)
                    .disabledCustomizationBehavior(.reorder)

                    TableColumn("Dimensions") { item in
                        FileMetadataCell(column: .dimensions, item: item)
                            .foregroundColor(paneState.selection.contains(item.url) ? .primary : theme.ink.secondary)
                    }
                    .width(min: 80, ideal: 120, max: 160)
                    .customizationID(FileColumn.dimensions.rawValue)
                    .disabledCustomizationBehavior(.reorder)

                    TableColumn("Type") { item in
                        FileMetadataCell(column: .kind, item: item)
                            .foregroundColor(paneState.selection.contains(item.url) ? .primary : theme.ink.secondary)
                    }
                    .width(min: 80, ideal: 120, max: 160)
                    .customizationID(FileColumn.kind.rawValue)
                    .disabledCustomizationBehavior(.reorder)

                    TableColumn("Size") { item in
                        FileMetadataCell(column: .size, item: item)
                            .foregroundColor(paneState.selection.contains(item.url) ? .primary : theme.ink.secondary)
                    }
                    .width(min: 80, ideal: 120, max: 160)
                    .customizationID(FileColumn.size.rawValue)
                    .disabledCustomizationBehavior(.reorder)
                }
                .tableStyle(.inset)
                .contextMenu(forSelectionType: URL.self) { targets in
                    FileBrowserContextMenu(paneState: paneState, targetIDs: targets)
                }
                .scrollContentBackground(.hidden)
                .alternatingRowBackgrounds(.disabled)
                .background(theme.background)
            }
        }
    }
}

private struct FileBrowserContextMenu: View {
    @ObservedObject var paneState: PaneState
    let targetIDs: Set<URL>

    private var renameItem: FileItem? {
        guard targetIDs.count == 1, let target = targetIDs.first else { return nil }
        return paneState.visibleItems.first(where: { $0.id == target })?.item
    }

    var body: some View {
        Button("Open") { paneState.navigateIn() }
        Button("Open with Default App") {
            if let selectedID = paneState.selection.first,
               let item = paneState.visibleItems.first(where: { $0.id == selectedID }) {
                NSWorkspace.shared.open(item.item.url)
            }
        }
        Button("Reveal in Finder") { NSWorkspace.shared.selectFile(nil, inFileViewerRootedAtPath: paneState.currentDirectory.path) }
        Divider()
        Button("New Folder") { paneState.createNewFolder() }
        Button("Rename...") {
            paneState.renameTarget = renameItem
        }
        .disabled(renameItem == nil)
        Button("Move to Trash") { paneState.confirmMoveSelectionToTrash() }
        Divider()
        Button(targetIDs.count > 1 ? "Copy Full Paths" : "Copy Full Path") {
            let paths = targetIDs.isEmpty ? [paneState.currentDirectory.path] : targetIDs.map(\.path).sorted()
            NSPasteboard.general.clearContents()
            NSPasteboard.general.setString(paths.joined(separator: "\n"), forType: .string)
        }
    }
}

struct AuraPathHeader: View {
    @Environment(\.fileManagerPalette)
    private var theme
    @ObservedObject var paneState: PaneState
    
    var body: some View {
        HStack(spacing: 4) {
            if paneState.soloRoot != nil {
                Button(action: {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                        paneState.exitSoloMode()
                    }
                }) {
                    HStack(spacing: 4) {
                        Image(systemName: "arrow.backward.circle.fill")
                        Text("Exit Solo")
                    }
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(theme.ink.blue)
                }
                .buttonStyle(.plain)
                .padding(.trailing, 8)
                
                ThemeDivider(vertical: true).frame(height: 12)
            }
            
            let path = paneState.breadcrumbs
            Image(systemName: paneState.soloRoot == nil ? "sparkles" : "scope")
                .foregroundColor(theme.ink.blue)
                .font(.system(size: 10))
            
            ForEach(path.indices, id: \.self) { index in
                Text(path[index].path == "/" ? "/" : path[index].lastPathComponent)
                    .font(.system(size: 10, weight: .medium, design: .monospaced))
                    .padding(.vertical, 4)
                    .contentShape(Rectangle())
                    .onTapGesture(count: 2) { paneState.updateDirectory(path[index]) }
                    .help("Double-click to browse \(path[index].path)")
                    .accessibilityAddTraits(.isButton)
                    .accessibilityAction { paneState.updateDirectory(path[index]) }
                if index < path.count - 1 {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 8))
                        .foregroundColor(theme.ink.secondary)
                }
            }
            Spacer()
        }
        .padding(.horizontal, 12)
        .frame(height: 24)
        .background(theme.bg2)
        .overlay(ThemeDivider(), alignment: .bottom)
    }
}

struct VerticalTreePane: View {
    @Environment(\.fileManagerPalette)
    private var theme
    @ObservedObject var paneState: PaneState
    let isFocused: Bool
    
    var body: some View {
        GeometryReader { geometry in
            ScrollView(.horizontal) {
                treeContent
                    .frame(width: max(geometry.size.width, metadataWidth + 128), height: geometry.size.height)
            }
        }
    }

    private var metadataWidth: CGFloat {
        paneState.displayedColumns.filter { $0 != .name }.reduce(0) { $0 + $1.treeWidth }
    }

    private var treeContent: some View {
        VStack(spacing: 0) {
            // Header Row
            HStack(spacing: 0) {
                SortHeader(title: "Name", field: .name, paneState: paneState)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.leading, 32)
                ForEach(paneState.displayedColumns.filter { $0 != .name }) { column in
                    Group {
                        switch column {
                        case .created: SortHeader(title: column.title, field: .created, paneState: paneState)
                        case .modified: SortHeader(title: column.title, field: .modified, paneState: paneState)
                        default: Text(column.title)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: column == .size ? .trailing : .leading)
                    .padding(.horizontal, 8)
                    .frame(width: column.treeWidth)
                    .overlay(alignment: .leading) { ThemeDivider(vertical: true).padding(.vertical, 4) }
                }
            }
            .font(.system(size: 11, weight: .bold))
            .foregroundColor(theme.ink.secondary)
            .frame(height: 24)
            .background(theme.bg2)
            .contentShape(Rectangle())
            .contextMenu { ColumnVisibilityMenu(paneState: paneState) }
            
            ThemeDivider()
            
            ScrollViewReader { proxy in
                List(selection: $paneState.selection) {
                    ForEach(paneState.visibleItems) { treeItem in
                        TreeRowView(
                            treeItem: treeItem,
                            paneState: paneState,
                            isFocused: isFocused
                        )
                        .id(treeItem.id) // Set ID for scrolling
                        .tag(treeItem.id)
                        .itemProvider { NSItemProvider(object: treeItem.item.url as NSURL) }
                        .listRowInsets(EdgeInsets())
                        .listRowSeparator(.hidden)
                        .listRowBackground(theme.background)
                    }
                }
                .contextMenu(forSelectionType: URL.self) { targets in
                    FileBrowserContextMenu(paneState: paneState, targetIDs: targets)
                } primaryAction: { selection in
                    guard let item = paneState.visibleItems.first(where: { selection.contains($0.id) }) else { return }
                    paneState.activate(item.item)
                }
                .listStyle(.plain)
                .scrollContentBackground(.hidden)
                .background(theme.background)
                .onChange(of: paneState.selection) { _, newSelection in
                    SoundManager.shared.play(.click)
                    if newSelection.count == 1, let first = newSelection.first {
                        // Keep visible rows stationary between clicks. Keyboard and
                        // search selection still reveal rows outside the viewport.
                        proxy.scrollTo(first)
                    }
                }
            }
            .onDrop(of: [.fileURL], isTargeted: nil) { providers in
                handleDrop(providers: providers, targetURL: paneState.currentDirectory, paneState: paneState)
                return true
            }
        }
    }
}

struct TreeRowView: View {
    @Environment(\.fileManagerPalette)
    private var theme
    let treeItem: VisibleTreeItem
    @ObservedObject var paneState: PaneState
    let isFocused: Bool
    
    @State private var isTargeted = false
    @State private var isHovered = false
    
    var isExpanded: Bool {
        paneState.expandedItems.contains(treeItem.item.url)
    }

    @AppStorage("aura.showGuideLines")
    private var showGuideLines = true
    @AppStorage("aura.gitAuraEnabled")
    private var showGitStatus = true

    private var selected: Bool { paneState.selection.contains(treeItem.id) }
    private var ink: ThemeInk { (isHovered || isTargeted) && !selected ? theme.raisedInk : theme.ink }

    var body: some View {
        HStack(spacing: 0) {
            // Name Column with Guide Lines
            HStack(spacing: 0) {
                ForEach(0..<treeItem.level, id: \.self) { depth in
                    ZStack {
                        if showGuideLines && treeItem.parentLineStates[depth] {
                            Rectangle()
                                .fill(theme.rule2)
                                .frame(width: 1.5)
                                .padding(.leading, 10)
                        }
                    }
                    .frame(width: 20)
                }
                
                HStack(spacing: 4) {
                    if treeItem.item.isDirectory {
                        Image(systemName: "chevron.right")
                            .font(.system(size: 9))
                            .rotationEffect(isExpanded ? .degrees(90) : .zero)
                            .foregroundColor(ink.secondary)
                            .frame(width: 24, height: 24)
                            .contentShape(Rectangle())
                            .onTapGesture {
                                SoundManager.shared.play(.expansion)
                                withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                                    paneState.toggleExpansion(for: treeItem.item)
                                }
                            }
                    } else {
                        Spacer().frame(width: 24)
                    }
                    
                    Image(systemName: treeItem.item.isSymbolicLink || treeItem.item.isAlias ? "link" : (treeItem.item.isDirectory ? "folder.fill" : "doc.fill"))
                        .foregroundColor(ink.kind(for: treeItem.item))
                        .frame(width: 16)

                    Text(treeItem.item.name)
                        .lineLimit(1)
                        .fontWeight(paneState.selection.contains(treeItem.id) ? .bold : .regular)
                        .foregroundColor(ink.name(for: treeItem.item))
                    if showGitStatus { GitStatusBadge(status: treeItem.item.gitStatus, ink: ink) }
                }
                .frame(height: 24)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            ForEach(paneState.displayedColumns.filter { $0 != .name }) { column in
                FileMetadataCell(column: column, item: treeItem.item)
                    .font(.system(size: 10))
                    .foregroundColor(selected ? ink.primary : ink.secondary)
                    .padding(.horizontal, 8)
                    .frame(width: column.treeWidth)
            }
        }
        .padding(.vertical, 2)
        .background(SelectionBackground(selected: selected, focused: isFocused, hovered: isHovered || isTargeted))
        .overlay {
            if isTargeted { Rectangle().stroke(theme.ink.blue, lineWidth: 2) }
        }
        .contentShape(Rectangle())
        .onHover { hovering in
            isHovered = hovering
        }
        .onDrop(of: [.fileURL], isTargeted: $isTargeted) { providers in
            if treeItem.item.isDirectory {
                handleDrop(providers: providers, targetURL: treeItem.item.url, paneState: paneState)
                return true
            }
            return false
        }
    }
}

struct SortHeader: View {
    @Environment(\.fileManagerPalette)
    private var theme
    let title: String
    let field: SortField
    @ObservedObject var paneState: PaneState
    
    var body: some View {
        Button(action: {
            if paneState.sortField == field {
                paneState.sortOrder = (paneState.sortOrder == .ascending) ? .descending : .ascending
            } else {
                paneState.sortField = field
                paneState.sortOrder = .ascending
            }
        }) {
            HStack(spacing: 4) {
                Text(title)
                    .foregroundColor(paneState.sortField == field ? theme.ink.primary : theme.ink.secondary)
                if paneState.sortField == field {
                    Image(systemName: paneState.sortOrder == .ascending ? "chevron.up" : "chevron.down")
                        .font(.system(size: 8))
                        .foregroundColor(theme.ink.blue)
                }
            }
        }
        .buttonStyle(.plain)
    }
}

private func handleDrop(providers: [NSItemProvider], targetURL: URL, paneState: PaneState) {
    for provider in providers {
        provider.loadObject(ofClass: NSURL.self) { url, _ in
            if let sourceURL = url as? URL {
                DispatchQueue.main.async {
                    paneState.moveItem(at: sourceURL, to: targetURL)
                }
            }
        }
    }
}
