import SwiftUI

struct DualPaneView: View {
    @Environment(\.fileManagerPalette)
    private var theme
    @ObservedObject var state: BrowserState
    @FocusState private var isKeyboardFocused: Bool
    
    var body: some View {
        VStack(spacing: 0) {
            HSplitView {
                FileBrowserPane(
                    paneState: state.left,
                    isFocused: state.focusedPane == .left,
                    acceptsPointerActivation: !state.isCommandPalettePresented,
                    activate: { activatePane(.left) }
                )
                .frame(minWidth: 300, maxWidth: .infinity)

                FileBrowserPane(
                    paneState: state.right,
                    isFocused: state.focusedPane == .right,
                    acceptsPointerActivation: !state.isCommandPalettePresented,
                    activate: { activatePane(.right) }
                )
                .frame(minWidth: 300, maxWidth: .infinity)
            }
            
            ThemeDivider()
            
            // Status Bar
            HStack {
                StatusInfo(paneState: state.left)
                ThemeDivider(vertical: true).frame(height: 12)
                StatusInfo(paneState: state.right)
            }
            .frame(height: 24)
            .padding(.horizontal, 8)
            .background(theme.bg2)
            .font(.system(size: 11))
            .foregroundColor(theme.ink.secondary)
        }
        .focusable(true)
        .focused($isKeyboardFocused)
        .onChange(of: state.isCommandPalettePresented) { _, presented in
            if presented { isKeyboardFocused = false } else { reclaimKeyboardFocus() }
        }
        .onKeyPress(.tab) {
            state.toggleFocus()
            return .handled
        }
        .onKeyPress(.upArrow, phases: [.down, .repeat]) { press in
            // Let the native list extend or contract its selection range.
            guard !press.modifiers.contains(.shift) else { return .ignored }
            state.activePane.selectPrevious()
            return .handled
        }
        .onKeyPress(.downArrow, phases: [.down, .repeat]) { press in
            guard !press.modifiers.contains(.shift) else { return .ignored }
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
        .onChange(of: state.left.mode) { _, newMode in
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

    private func activatePane(_ pane: PaneFocus) {
        // Let the clicked native control keep its own first responder and selection.
        if state.focusedPane != pane { state.focusedPane = pane }
    }

    private func reclaimKeyboardFocus() {
        DispatchQueue.main.async {
            guard !state.isCommandPalettePresented, case .browser = state.activePane.mode else { return }
            isKeyboardFocused = true
        }
    }
}

struct StatusInfo: View {
    @Environment(\.fileManagerPalette)
    private var theme
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
