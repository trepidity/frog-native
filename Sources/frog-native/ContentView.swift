import SwiftUI

struct ContentView: View {
    @ObservedObject var state: BrowserState
    
    var body: some View {
        ZStack {
            VisualEffectView(material: .sidebar, blendingMode: .behindWindow)
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
                        Text("⌘K").opacity(0.5)
                    }
                    .buttonStyle(.bordered)
                    .keyboardShortcut("k", modifiers: .command)
                    .padding(8)
                }
                .frame(height: 40)
                .background(Color.clear)
                
                Divider()
                
                DualPaneView(state: state)
            }
            .blur(radius: state.isCommandPalettePresented ? 10 : 0)
            
            if state.isCommandPalettePresented {
                Color.black.opacity(0.2)
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
