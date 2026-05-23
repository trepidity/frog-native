import SwiftUI

struct HelpGuideView: View {
    @ObservedObject var paneState: PaneState
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Button(action: { 
                    withAnimation(.spring(response: 0.3)) {
                        paneState.closeEditor()
                    }
                }) {
                    HStack(spacing: 4) {
                        Image(systemName: "arrow.left")
                        Text("Back to Tree")
                    }
                }
                .buttonStyle(.plain)
                .font(.system(size: 10, weight: .bold))
                .foregroundColor(.accentColor)
                
                Spacer()
                
                Text("Aura Master Guide")
                    .font(.system(size: 11, weight: .bold))
                
                Spacer()
                
                Image(systemName: "book.closed")
                    .font(.system(size: 10))
                    .foregroundColor(.secondary)
            }
            .padding(.horizontal, 12)
            .frame(height: 32)
            .background(VisualEffectView(material: .headerView, blendingMode: .withinWindow))
            .overlay(Divider(), alignment: .bottom)
            
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    GuideSection(title: "The Staircase", icon: "staircase") {
                        GuideRow(key: "Arrows", desc: "Climb the hierarchy")
                        GuideRow(key: "Right", desc: "Expand folder")
                        GuideRow(key: "Left", desc: "Collapse folder")
                        GuideRow(key: "⏎", desc: "Enter file / folder")
                    }
                    
                    GuideSection(title: "Aura Spotlight", icon: "magnifyingglass") {
                        GuideRow(key: "⌘ K", desc: "Open Search")
                        GuideRow(key: "⏎", desc: "Jump & Reveal")
                        GuideRow(key: "⌘ ⏎", desc: "Instant Open")
                    }
                    
                    GuideSection(title: "Power Moves", icon: "sparkles") {
                        GuideRow(key: "⌘ ⇧ ⏎", desc: "Solo Mode (Isolated focus)")
                        GuideRow(key: "⌘ C", desc: "Rich Copy (URL + Image)")
                        GuideRow(key: "Space", desc: "Quick Look Preview")
                    }
                    
                    GuideSection(title: "Reading the Light", icon: "lightbulb") {
                        ColorInfo(color: .green, desc: "New Arrival (lasts 5s)")
                        ColorInfo(color: .orange, desc: "Recent Change (Hot)")
                        ColorInfo(color: .blue, desc: "Untouched (Cold)")
                    }
                }
                .padding(24)
            }
            .background(VisualEffectView(material: .sidebar, blendingMode: .withinWindow))
        }
    }
}

struct GuideSection<Content: View>: View {
    let title: String
    let icon: String
    let content: Content
    
    init(title: String, icon: String, @ViewBuilder content: () -> Content) {
        self.title = title
        self.icon = icon
        self.content = content()
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: icon)
                Text(title).bold()
            }
            .font(.system(size: 12))
            .foregroundColor(.accentColor)
            
            VStack(alignment: .leading, spacing: 8) {
                content
            }
        }
    }
}

struct GuideRow: View {
    let key: String
    let desc: String
    
    var body: some View {
        HStack {
            Text(key)
                .font(.system(size: 10, weight: .bold, design: .monospaced))
                .frame(width: 60, alignment: .leading)
            Text(desc)
                .font(.system(size: 11))
                .foregroundColor(.secondary)
        }
    }
}

struct ColorInfo: View {
    let color: Color
    let desc: String
    
    var body: some View {
        HStack(spacing: 8) {
            Circle()
                .fill(color)
                .frame(width: 8, height: 8)
            Text(desc)
                .font(.system(size: 11))
                .foregroundColor(.secondary)
        }
    }
}
