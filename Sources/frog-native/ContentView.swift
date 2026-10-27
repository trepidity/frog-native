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
                HStack {
                    Text("Frog Native")
                        .font(.system(size: 13, weight: .bold))
                        .padding(.leading, 80) // Space for traffic lights
                    Spacer()
                    
                    Button(action: { state.isCommandPalettePresented.toggle() }) {
                        Image(systemName: "magnifyingglass")
                        Text("Search or Action...")
                        Text("⌘K").foregroundStyle(theme.ink.secondary)
                    }
                    .buttonStyle(.bordered)
                    .keyboardShortcut("k", modifiers: .command)
                    .padding(8)
                }
                .frame(height: 40)
                .background(theme.bg2)
                
                ThemeDivider()
                
                DualPaneView(state: state)
            }
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
