import SwiftUI

struct ContentView: View {
    @Environment(\.fileManagerPalette) private var theme
    @ObservedObject var state: BrowserState
    
    var body: some View {
        ZStack {
            theme.bg
                .ignoresSafeArea()
            
            VStack(spacing: 0) {
                // Header
                HStack(alignment: .top) {
                    Text("Frog Native")
                        .font(.system(size: 13, weight: .bold))
                        .frame(height: 28)
                        .padding(.leading, 80) // Space for traffic lights
                    Spacer()

                    Button(action: { state.isCommandPalettePresented.toggle() }) {
                        HStack(spacing: 6) {
                            Image(systemName: "magnifyingglass")
                            Text("Search or Action...")
                            Text("⌘K").foregroundStyle(theme.ink.secondary)
                        }
                        .font(.system(size: 13))
                        .padding(.horizontal, 12)
                        .frame(height: 36)
                        .background(theme.panel2, in: RoundedRectangle(cornerRadius: 6))
                        .overlay(RoundedRectangle(cornerRadius: 6).stroke(theme.rule2, lineWidth: 1))
                        .contentShape(RoundedRectangle(cornerRadius: 6))
                    }
                    .buttonStyle(.plain)
                    .keyboardShortcut("k", modifiers: .command)
                    .padding(.vertical, 4)
                    .padding(.trailing, 8)
                }
                .frame(height: 44)
                .background(theme.bg2)
                
                ThemeDivider()
                
                DualPaneView(state: state)
            }
            .ignoresSafeArea(.container, edges: .top)
            .blur(radius: state.isCommandPalettePresented ? 10 : 0)
            
            if state.isCommandPalettePresented {
                theme.bg2.opacity(0.65)
                    .ignoresSafeArea()
                    .onTapGesture {
                        state.isCommandPalettePresented = false
                    }
                
                CommandPaletteView(state: state)
                    .transition(.scale(scale: 0.9).combined(with: .opacity))
            }
        }
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: state.isCommandPalettePresented)
        .frame(minWidth: 800, minHeight: 600)
    }
}

struct VisualEffectView: NSViewRepresentable {
    var material: NSVisualEffectView.Material
    var blendingMode: NSVisualEffectView.BlendingMode

    func makeNSView(context: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        view.material = material
        view.blendingMode = blendingMode
        view.state = .active
        return view
    }

    func updateNSView(_ nsView: NSVisualEffectView, context: Context) {
        nsView.material = material
        nsView.blendingMode = blendingMode
    }
}
