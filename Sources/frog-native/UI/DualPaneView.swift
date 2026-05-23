import SwiftUI

struct DualPaneView: View {
    @ObservedObject var state: BrowserState
    @FocusState private var isKeyboardFocused: Bool
    
    var body: some View {
        VStack(spacing: 0) {
            HSplitView {
                FileBrowserPane(
                    paneState: state.left,
                    isFocused: state.focusedPane == .left,
                    layout: state.currentLayout
                )
                .frame(minWidth: 300, maxWidth: .infinity)
                .contentShape(Rectangle())
                .onTapGesture {
                    state.focusedPane = .left
                    reclaimKeyboardFocus()
                }
                
                FileBrowserPane(
                    paneState: state.right,
                    isFocused: state.focusedPane == .right,
                    layout: state.currentLayout
                )
                .frame(minWidth: 300, maxWidth: .infinity)
                .contentShape(Rectangle())
                .onTapGesture {
                    state.focusedPane = .right
                    reclaimKeyboardFocus()
                }
            }
            
            Divider()
            
            // Status Bar
            HStack {
                StatusInfo(paneState: state.left)
                Divider().frame(height: 12)
                StatusInfo(paneState: state.right)
            }
            .frame(height: 24)
            .padding(.horizontal, 8)
            .background(Color(NSColor.windowBackgroundColor))
            .font(.system(size: 11))
            .foregroundColor(.secondary)
        }
        .focusable(true)
        .focused($isKeyboardFocused)
        .onKeyPress(.tab) {
            state.toggleFocus()
            return .handled
        }
        .onKeyPress(.upArrow) {
            state.activePane.selectPrevious()
            return .handled
        }
        .onKeyPress(.downArrow) {
            state.activePane.selectNext()
            return .handled
        }
        .onKeyPress(.leftArrow) {
            state.activePane.handleLeftArrow()
            return .handled
        }
        .onKeyPress(.rightArrow) {
            state.activePane.handleRightArrow()
            return .handled
        }
        .onKeyPress(.return) {
            state.activePane.navigateIn()
            return .handled
        }
        .onKeyPress(.escape) {
            if case .editor = state.activePane.mode {
                state.activePane.closeEditor()
                reclaimKeyboardFocus()
                return .handled
            }
            return .ignored
        }
        .onAppear {
            reclaimKeyboardFocus()
        }
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("reclaimAuraFocus"))) { _ in
            reclaimKeyboardFocus()
        }
        .onChange(of: state.left.mode) { oldValue, newMode in
            if case .browser = newMode, state.focusedPane == .left {
                reclaimKeyboardFocus()
            }
        }
        .onChange(of: state.right.mode) { _, newMode in
            if case .browser = newMode, state.focusedPane == .right {
                reclaimKeyboardFocus()
            }
        }
    }

    private func reclaimKeyboardFocus() {
        DispatchQueue.main.async {
            isKeyboardFocused = true
        }
    }
}

struct StatusInfo: View {
    @ObservedObject var paneState: PaneState
    
    var body: some View {
        let visibleItems = paneState.visibleItems
        let selectedItems = visibleItems.filter { paneState.selection.contains($0.id) }

        HStack {
            if selectedItems.isEmpty {
                Text("\(visibleItems.count) items")
            } else {
                let totalSize = selectedItems.reduce(into: 0) { $0 += $1.item.size }
                Text("\(selectedItems.count) of \(visibleItems.count) selected")
                if totalSize > 0 {
                    Text("(\(ByteCountFormatter.string(fromByteCount: totalSize, countStyle: .file)))")
                }
            }
            Spacer()
        }
    }
}
