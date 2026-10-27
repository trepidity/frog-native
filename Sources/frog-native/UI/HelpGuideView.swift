import SwiftUI

struct HelpGuideView: View {
    @Environment(\.fileManagerPalette)
    private var theme
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
                .foregroundColor(theme.ink.blue)
                
                Spacer()
                
                Text("Aura Master Guide")
                    .font(.system(size: 11, weight: .bold))
                
                Spacer()
                
                Image(systemName: "book.closed")
                    .font(.system(size: 10))
                    .foregroundColor(theme.ink.secondary)
            }
            .padding(.horizontal, 12)
            .frame(height: 32)
            .background(theme.bg2)
            .overlay(ThemeDivider(), alignment: .bottom)
            
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
                    
                    GuideSection(title: "Solarized", icon: "paintpalette") {
                        ColorInfo(color: theme.ink.blue, desc: "Folders and the focused selection bar")
                        ColorInfo(color: theme.ink.good, desc: "Git: Added")
                        ColorInfo(color: theme.ink.warn, desc: "Git: Modified")
                        ColorInfo(color: theme.ink.bad, desc: "Git: Deleted")
                        GuideRow(key: "⌘ ,", desc: "Choose Solarized Dark or Light in Preferences")
                    }
                }
                .padding(24)
            }
            .background(theme.background)
        }
    }
}

struct GuideSection<Content: View>: View {
    @Environment(\.fileManagerPalette)
    private var theme
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
            .foregroundColor(theme.ink.blue)
            
            VStack(alignment: .leading, spacing: 8) {
                content
            }
        }
    }
}

struct GuideRow: View {
    @Environment(\.fileManagerPalette)
    private var theme
    let key: String
    let desc: String
    
    var body: some View {
        HStack {
            Text(key)
                .font(.system(size: 10, weight: .bold, design: .monospaced))
                .frame(width: 60, alignment: .leading)
            Text(desc)
                .font(.system(size: 11))
                .foregroundColor(theme.ink.secondary)
        }
    }
}

struct ColorInfo: View {
    @Environment(\.fileManagerPalette)
    private var theme
    let color: Color
    let desc: String
    
    var body: some View {
        HStack(spacing: 8) {
            Circle()
                .fill(color)
                .frame(width: 8, height: 8)
            Text(desc)
                .font(.system(size: 11))
                .foregroundColor(theme.ink.secondary)
        }
    }
}
