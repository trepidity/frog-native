import SwiftUI
import _QuickLook_SwiftUI

struct FileBrowserPane: View {
    @Environment(\.fileManagerPalette) private var theme
    @ObservedObject var paneState: PaneState
    let isFocused: Bool
    let layout: LayoutType
    
    var body: some View {
        VStack(spacing: 0) {
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
        .background(theme.bg)
        .overlay(
            RoundedRectangle(cornerRadius: 0)
                .stroke(isFocused ? theme.ink.blue : theme.rule, lineWidth: isFocused ? 2 : 1)
        )
        .contextMenu {
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
                print("Rename requested") 
            }
            Button("Move to Trash") { paneState.confirmMoveSelectionToTrash() }
            Divider()
            Button("Copy Path") { NSPasteboard.general.clearContents(); NSPasteboard.general.setString(paneState.currentDirectory.path, forType: .string) }
        }
        .auraQuickLookPreview($paneState.previewURL)
    }

    @ViewBuilder private var browserView: some View {
        VStack(spacing: 0) {
            // Sticky Aura Breadcrumbs
            if layout == .verticalTree {
                AuraPathHeader(paneState: paneState)
            }
            
            // Content Body
            if layout == .classic {
                List(paneState.items, selection: $paneState.selection) { item in
                    HStack {
                        Image(systemName: item.isDirectory ? "folder.fill" : "doc.fill")
                            .foregroundColor(paneState.selection.contains(item.url) ? .primary : theme.ink.kind(for: item))
                        Text(item.name).foregroundColor(paneState.selection.contains(item.url) ? .primary : theme.ink.name(for: item))
                    }
                    .onDrag {
                        NSItemProvider(object: item.url as NSURL)
                    }
                }
                .listStyle(.inset)
                .scrollContentBackground(.hidden)
                .alternatingRowBackgrounds(.disabled)
                .background(theme.bg)
                .onDrop(of: [.fileURL], isTargeted: nil) { providers in
                    handleDrop(providers: providers, targetURL: paneState.currentDirectory, paneState: paneState)
                    return true
                }
            } else if layout == .verticalTree {
                VerticalTreePane(paneState: paneState, isFocused: isFocused)
            } else {
                // Table view for Pro and Staircase
                Table(paneState.items, selection: $paneState.selection) {
                    TableColumn("Name") { item in
                        HStack {
                            Image(systemName: item.isDirectory ? "folder.fill" : "doc.fill")
                                .foregroundColor(paneState.selection.contains(item.url) ? .primary : theme.ink.kind(for: item))
                                .frame(width: 16)
                            Text(item.name).foregroundColor(paneState.selection.contains(item.url) ? .primary : theme.ink.name(for: item))
                        }
                    }
                    
                    TableColumn("Size") { item in
                        Text(item.isDirectory ? "--" : ByteCountFormatter.string(fromByteCount: item.size, countStyle: .file))
                            .foregroundColor(paneState.selection.contains(item.url) ? .primary : theme.ink.secondary)
                            .font(.system(.body, design: .monospaced))
                    }
                    .width(min: 80, max: 120)
                    
                    TableColumn("Modified") { item in
                        Text(item.modificationDate, style: .date)
                            .foregroundColor(paneState.selection.contains(item.url) ? .primary : theme.ink.secondary)
                    }
                    .width(min: 100, max: 150)
                }
                .tableStyle(.inset)
                .scrollContentBackground(.hidden)
                .alternatingRowBackgrounds(.disabled)
                .background(theme.bg)
            }
        }
    }
}

struct AuraPathHeader: View {
    @Environment(\.fileManagerPalette) private var theme
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
    @Environment(\.fileManagerPalette) private var theme
    @ObservedObject var paneState: PaneState
    let isFocused: Bool
    
    var body: some View {
        VStack(spacing: 0) {
            // Header Row
            HStack(spacing: 0) {
                SortHeader(title: "Name", field: .name, paneState: paneState)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.leading, 32)
                ThemeDivider(vertical: true).padding(.vertical, 4)
                
                if paneState.context == .assets {
                    Text("Dimensions")
                        .frame(width: 120, alignment: .leading)
                        .padding(.leading, 8)
                    ThemeDivider(vertical: true).padding(.vertical, 4)
                    Text("Type")
                        .frame(width: 120, alignment: .leading)
                        .padding(.leading, 8)
                } else {
                    SortHeader(title: "Created", field: .created, paneState: paneState)
                        .frame(width: 120, alignment: .leading)
                        .padding(.leading, 8)
                    ThemeDivider(vertical: true).padding(.vertical, 4)
                    SortHeader(title: "Modified", field: .modified, paneState: paneState)
                        .frame(width: 120, alignment: .leading)
                        .padding(.leading, 8)
                }
                ThemeDivider(vertical: true).padding(.vertical, 4)
                Text("Size")
                    .frame(width: 80, alignment: .trailing)
                    .padding(.horizontal, 8)
            }
            .font(.system(size: 11, weight: .bold))
            .foregroundColor(theme.ink.secondary)
            .frame(height: 24)
            .background(theme.bg2)
            
            ThemeDivider()
            
            ScrollViewReader { proxy in
                List {
                    ForEach(paneState.visibleItems) { treeItem in
                        TreeRowView(
                            treeItem: treeItem,
                            paneState: paneState,
                            isFocused: isFocused
                        )
                        .id(treeItem.id) // Set ID for scrolling
                        .listRowInsets(EdgeInsets())
                        .listRowSeparator(.hidden)
                        .listRowBackground(theme.bg)
                    }
                }
                .listStyle(.plain)
                .scrollContentBackground(.hidden)
                .background(theme.bg)
                .onChange(of: paneState.selection) { _, newSelection in
                    if let first = newSelection.first {
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
    @Environment(\.fileManagerPalette) private var theme
    let treeItem: VisibleTreeItem
    @ObservedObject var paneState: PaneState
    let isFocused: Bool
    
    @State private var isTargeted = false
    @State private var isHovered = false
    
    var isExpanded: Bool {
        paneState.expandedItems.contains(treeItem.item.url)
    }

    @AppStorage("aura.showGuideLines") private var showGuideLines = true
    @AppStorage("aura.gitAuraEnabled") private var showGitStatus = true

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

            // Context-Aware Metadata Columns
            if paneState.context == .assets {
                Text(treeItem.item.dimensions ?? "--")
                    .font(.system(size: 10))
                    .foregroundColor(selected ? ink.primary : ink.secondary)
                    .frame(width: 120, alignment: .leading)
                    .padding(.leading, 8)
                
                Text(treeItem.item.fileTypeDescription ?? "--")
                    .font(.system(size: 10))
                    .foregroundColor(selected ? ink.primary : ink.secondary)
                    .frame(width: 120, alignment: .leading)
                    .padding(.leading, 8)
            } else {
                // Liquid Created Column
                if treeItem.level < 5 {
                    Text(treeItem.item.creationDate, style: treeItem.level < 3 ? .date : .offset)
                        .font(.system(size: 10))
                        .foregroundColor(selected ? ink.primary : ink.secondary)
                        .frame(width: treeItem.level < 3 ? 120 : 80, alignment: .leading)
                        .padding(.leading, 8)
                } else {
                    Image(systemName: "calendar.badge.plus")
                        .font(.system(size: 8))
                        .foregroundColor(ink.muted)
                        .frame(width: 30)
                }
                
                // Liquid Modified Column
                if treeItem.level < 4 {
                    Text(treeItem.item.modificationDate, style: treeItem.level < 2 ? .date : .offset)
                        .font(.system(size: 10))
                        .foregroundColor(selected ? ink.primary : ink.secondary)
                        .frame(width: treeItem.level < 2 ? 120 : 80, alignment: .leading)
                        .padding(.leading, 8)
                } else {
                    Image(systemName: "pencil.line")
                        .font(.system(size: 8))
                        .foregroundColor(ink.muted)
                        .frame(width: 30)
                }
            }

            Text(treeItem.item.isDirectory ? "--" : ByteCountFormatter.string(
                fromByteCount: treeItem.item.size,
                countStyle: .file
            ))
            .font(.system(size: 10, design: .monospaced))
            .foregroundColor(selected ? ink.primary : ink.secondary)
            .lineLimit(1)
            .frame(width: 80, alignment: .trailing)
            .padding(.horizontal, 8)
        }
        .padding(.vertical, 2)
        .background(SelectionBackground(selected: selected, focused: isFocused, hovered: isHovered || isTargeted))
        .overlay {
            if isTargeted { Rectangle().stroke(theme.ink.blue, lineWidth: 2) }
        }
        .contentShape(Rectangle())
        .simultaneousGesture(
            TapGesture(count: 2).onEnded {
                paneState.activate(treeItem.item)
            }
        )
        .simultaneousGesture(
            TapGesture().onEnded {
                SoundManager.shared.play(.click)
                paneState.selection = [treeItem.id]
            }
        )
        .onHover { hovering in
            isHovered = hovering
        }
        .onDrag {
            NSItemProvider(object: treeItem.item.url as NSURL)
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
    @Environment(\.fileManagerPalette) private var theme
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
