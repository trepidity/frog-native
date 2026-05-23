import SwiftUI
import _QuickLook_SwiftUI

struct FileBrowserPane: View {
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
        .background(isFocused ? Color.accentColor.opacity(0.02) : Color.clear)
        .overlay(
            RoundedRectangle(cornerRadius: 0)
                .stroke(isFocused ? Color.accentColor.opacity(0.5) : Color.clear, lineWidth: 2)
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
            Button("Move to Trash") { paneState.moveSelectionToTrash() }
            Divider()
            Button("Copy Path") { NSPasteboard.general.clearContents(); NSPasteboard.general.setString(paneState.currentDirectory.path, forType: .string) }
        }
        .auraQuickLookPreview($paneState.previewURL)
    }

    @ViewBuilder
    private var browserView: some View {
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
                        Text(item.name)
                    }
                    .onDrag {
                        NSItemProvider(object: item.url as NSURL)
                    }
                }
                .listStyle(.inset)
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
                                .foregroundColor(item.isDirectory ? .blue : .secondary)
                                .frame(width: 16)
                            Text(item.name)
                        }
                    }
                    
                    TableColumn("Size") { item in
                        Text(item.isDirectory ? "--" : ByteCountFormatter.string(fromByteCount: item.size, countStyle: .file))
                            .foregroundColor(.secondary)
                            .font(.system(.body, design: .monospaced))
                    }
                    .width(min: 80, max: 120)
                    
                    TableColumn("Modified") { item in
                        Text(item.modificationDate, style: .date)
                            .foregroundColor(.secondary)
                    }
                    .width(min: 100, max: 150)
                }
                .tableStyle(.inset)
            }
        }
    }
}

struct AuraPathHeader: View {
    @ObservedObject var paneState: PaneState
    
    var body: some View {
        HStack(spacing: 4) {
            if let _ = paneState.soloRoot {
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
                    .foregroundColor(.accentColor)
                }
                .buttonStyle(.plain)
                .padding(.trailing, 8)
                
                Divider().frame(height: 12)
            }
            
            let path = currentAuraPath()
            Image(systemName: paneState.soloRoot == nil ? "sparkles" : "scope")
                .foregroundColor(.accentColor)
                .font(.system(size: 10))
            
            ForEach(path.indices, id: \.self) { index in
                Text(path[index])
                    .font(.system(size: 10, weight: .medium, design: .monospaced))
                if index < path.count - 1 {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 8))
                        .foregroundColor(.secondary)
                }
            }
            Spacer()
        }
        .padding(.horizontal, 12)
        .frame(height: 24)
        .background(VisualEffectView(material: .headerView, blendingMode: .withinWindow))
        .overlay(Divider(), alignment: .bottom)
    }
    
    private func currentAuraPath() -> [String] {
        let activeRoot = paneState.soloRoot ?? paneState.currentDirectory
        
        guard let selectedID = paneState.selection.first,
              let item = paneState.visibleItems.first(where: { $0.id == selectedID }) else {
            return [activeRoot.lastPathComponent]
        }
        
        let fullPath = item.item.url.path
        let rootPath = activeRoot.path
        
        if fullPath == rootPath {
            return [activeRoot.lastPathComponent]
        }
        
        if fullPath.hasPrefix(rootPath) {
            let relative = fullPath.replacingOccurrences(of: rootPath, with: "")
            let components = relative.components(separatedBy: "/").filter { !$0.isEmpty }
            return [activeRoot.lastPathComponent] + components
        }
        
        return [item.item.name]
    }
}

struct VerticalTreePane: View {
    @ObservedObject var paneState: PaneState
    let isFocused: Bool
    
    var body: some View {
        VStack(spacing: 0) {
            // Header Row
            HStack(spacing: 0) {
                SortHeader(title: "Name", field: .name, paneState: paneState)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.leading, 32)
                Divider().padding(.vertical, 4)
                
                if paneState.context == .assets {
                    Text("Dimensions")
                        .frame(width: 120, alignment: .leading)
                        .padding(.leading, 8)
                        .opacity(isFocused ? 1.0 : 0.2)
                    Divider().padding(.vertical, 4)
                    Text("Type")
                        .frame(width: 120, alignment: .leading)
                        .padding(.leading, 8)
                        .opacity(isFocused ? 1.0 : 0.2)
                } else {
                    SortHeader(title: "Created", field: .created, paneState: paneState)
                        .frame(width: 120, alignment: .leading)
                        .padding(.leading, 8)
                        .opacity(isFocused ? 1.0 : 0.2)
                    Divider().padding(.vertical, 4)
                    SortHeader(title: "Modified", field: .modified, paneState: paneState)
                        .frame(width: 120, alignment: .leading)
                        .padding(.leading, 8)
                        .opacity(isFocused ? 1.0 : 0.2)
                }
            }
            .font(.system(size: 11, weight: .bold))
            .foregroundColor(.secondary)
            .frame(height: 24)
            .background(VisualEffectView(material: .titlebar, blendingMode: .withinWindow))
            
            Divider()
            
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
                        .listRowBackground(rowBackground(for: treeItem))
                    }
                }
                .listStyle(.plain)
                .onChange(of: paneState.selection) { _, newSelection in
                    if let first = newSelection.first {
                        withAnimation(.easeInOut) {
                            proxy.scrollTo(first, anchor: .center)
                        }
                    }
                }
            }
            .onDrop(of: [.fileURL], isTargeted: nil) { providers in
                handleDrop(providers: providers, targetURL: paneState.currentDirectory, paneState: paneState)
                return true
            }
        }
    }
    
    private func rowBackground(for treeItem: VisibleTreeItem) -> some View {
        ZStack {
            if paneState.selection.contains(treeItem.id) {
                Color.accentColor
            } else {
                compositeAura(for: treeItem.item, at: treeItem.level)
            }
            
            if treeItem.item.gitStatus != .clean && !paneState.selection.contains(treeItem.id) {
                gitColor(for: treeItem.item.gitStatus).opacity(0.12)
                    .blur(radius: 4)
            }
            
            // Birth Glow
            if paneState.recentArrivals[treeItem.item.url] != nil {
                Color.green.opacity(0.2)
            }
        }
    }
}

struct TreeRowView: View {
    let treeItem: VisibleTreeItem
    @ObservedObject var paneState: PaneState
    let isFocused: Bool
    
    @State private var isTargeted = false
    @State private var isHovered = false
    
    var isExpanded: Bool {
        paneState.expandedItems.contains(treeItem.item.url)
    }
    
    var body: some View {
        HStack(spacing: 0) {
            // Name Column with Guide Lines
            HStack(spacing: 0) {
                ForEach(0..<treeItem.level, id: \.self) { i in
                    ZStack {
                        if treeItem.parentLineStates[i] {
                            Rectangle()
                                .fill(gitColor(for: treeItem.item.gitStatus))
                                .frame(width: 1.5)
                                .padding(.leading, 10)
                                .shadow(color: gitColor(for: treeItem.item.gitStatus).opacity(0.5), radius: 2)
                        }
                    }
                    .frame(width: 20)
                }
                
                HStack(spacing: 4) {
                    if treeItem.item.isDirectory {
                        Image(systemName: "chevron.right")
                            .font(.system(size: 9))
                            .rotationEffect(isExpanded ? .degrees(90) : .zero)
                            .foregroundColor(.secondary)
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
                    
                    Image(systemName: treeItem.item.isDirectory ? "folder.fill" : "doc.fill")
                        .foregroundColor(treeItem.item.isDirectory ? .blue : .secondary)
                        .frame(width: 16)
                        .overlay(
                            Circle()
                                .fill(gitColor(for: treeItem.item.gitStatus))
                                .frame(width: 6, height: 6)
                                .offset(x: 6, y: 6)
                                .opacity(treeItem.item.gitStatus == .clean ? 0 : 1)
                        )
                    
                    Text(treeItem.item.name)
                        .lineLimit(1)
                        .fontWeight(paneState.selection.contains(treeItem.id) ? .bold : .regular)
                        .foregroundColor(treeItem.item.gitStatus == .clean ? (paneState.selection.contains(treeItem.id) ? .white : .primary) : gitColor(for: treeItem.item.gitStatus))
                    }
                    .frame(height: 24)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)            
            // Context-Aware Metadata Columns
            if paneState.context == .assets {
                Text(treeItem.item.dimensions ?? "--")
                    .font(.system(size: 10))
                    .foregroundColor(paneState.selection.contains(treeItem.id) ? .white.opacity(0.8) : .secondary)
                    .frame(width: 120, alignment: .leading)
                    .padding(.leading, 8)
                    .opacity(isFocused ? 0.8 : 0.2)
                
                Text(treeItem.item.fileTypeDescription ?? "--")
                    .font(.system(size: 10))
                    .foregroundColor(paneState.selection.contains(treeItem.id) ? .white.opacity(0.8) : .secondary)
                    .frame(width: 120, alignment: .leading)
                    .padding(.leading, 8)
                    .opacity(isFocused ? 0.8 : 0.2)
            } else {
                // Liquid Created Column
                if treeItem.level < 5 {
                    Text(treeItem.item.creationDate, style: treeItem.level < 3 ? .date : .offset)
                        .font(.system(size: 10))
                        .foregroundColor(paneState.selection.contains(treeItem.id) ? .white.opacity(0.8) : .secondary)
                        .frame(width: treeItem.level < 3 ? 120 : 80, alignment: .leading)
                        .padding(.leading, 8)
                        .opacity(isFocused ? 0.8 : 0.2)
                } else {
                    Image(systemName: "calendar.badge.plus")
                        .font(.system(size: 8))
                        .foregroundColor(paneState.selection.contains(treeItem.id) ? .white.opacity(0.5) : .secondary.opacity(0.3))
                        .frame(width: 30)
                }
                
                // Liquid Modified Column
                if treeItem.level < 4 {
                    Text(treeItem.item.modificationDate, style: treeItem.level < 2 ? .date : .offset)
                        .font(.system(size: 10))
                        .foregroundColor(paneState.selection.contains(treeItem.id) ? .white.opacity(0.8) : .secondary)
                        .frame(width: treeItem.level < 2 ? 120 : 80, alignment: .leading)
                        .padding(.leading, 8)
                        .opacity(isFocused ? 0.8 : 0.2)
                } else {
                    Image(systemName: "pencil.line")
                        .font(.system(size: 8))
                        .foregroundColor(paneState.selection.contains(treeItem.id) ? .white.opacity(0.5) : .secondary.opacity(0.3))
                        .frame(width: 30)
                }
            }
        }
        .padding(.vertical, 2)
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
            withAnimation(.easeInOut(duration: 0.2)) {
                isHovered = hovering
            }
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

// Global Helpers (Keeping them outside for easy access)
private func gitColor(for status: FileItem.GitStatus) -> Color {
    switch status {
    case .added, .untracked: return .green
    case .modified: return .orange
    case .deleted: return .red
    case .clean: return .secondary.opacity(0.3)
    }
}

private func compositeAura(for item: FileItem, at level: Int) -> some View {
    ZStack {
        if level > 0 {
            Color.primary.opacity(min(Double(level) * 0.04, 0.12))
        }
        let score = item.recencyScore
        if score > 0 {
            Color.orange.opacity(score * 0.15).blendMode(.screen)
        } else {
            Color.blue.opacity(0.05).blendMode(.multiply)
        }
    }
}

struct SortHeader: View {
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
                if paneState.sortField == field {
                    Image(systemName: paneState.sortOrder == .ascending ? "chevron.up" : "chevron.down")
                        .font(.system(size: 8))
                }
            }
        }
        .buttonStyle(.plain)
    }
}

private func handleDrop(providers: [NSItemProvider], targetURL: URL, paneState: PaneState) {
    for provider in providers {
        provider.loadObject(ofClass: NSURL.self) { url, error in
            if let sourceURL = url as? URL {
                DispatchQueue.main.async {
                    paneState.moveItem(at: sourceURL, to: targetURL)
                }
            }
        }
    }
}
