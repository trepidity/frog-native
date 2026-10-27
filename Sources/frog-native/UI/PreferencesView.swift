import SwiftUI

struct PreferencesView: View {
    @ObservedObject var browser: BrowserState
    @Environment(\.fileManagerPalette)
    private var theme
    @StateObject private var settings = AuraSettings.shared
    
    var body: some View {
        TabView {
            GeneralPreferencesView(browser: browser)
                .tabItem {
                    Label("General", systemImage: "gearshape")
                }
            
            AuraPreferencesView(settings: settings)
                .tabItem {
                    Label("Appearance", systemImage: "paintpalette")
                }
            
            SensoryPreferencesView(settings: settings)
                .tabItem {
                    Label("Senses", systemImage: "speaker.wave.2")
                }
        }
        .frame(width: 450, height: 350)
        .padding(20)
        .background(theme.panel)
    }
}

struct GeneralPreferencesView: View {
    @ObservedObject var browser: BrowserState
    
    var body: some View {
        Form {
            Section("Left Pane") {
                PanePreferencesView(pane: browser.left)
            }
            Section("Right Pane") {
                PanePreferencesView(pane: browser.right)
            }
        }
    }
}

private struct PanePreferencesView: View {
    @ObservedObject var pane: PaneState
    var body: some View {
        Picker("Layout", selection: $pane.currentLayout) {
            ForEach(LayoutType.allCases, id: \.self) { layout in
                Text(layout.rawValue).tag(layout)
            }
        }
        Toggle("Show hidden files and folders", isOn: Binding(
            get: { pane.showHiddenFiles }, set: { pane.setHiddenFilesVisible($0) }
        ))
    }
}

struct AuraPreferencesView: View {
    @Environment(\.fileManagerPalette)
    private var theme
    @ObservedObject var settings: AuraSettings
    @AppStorage(FileManagerTheme.preferenceKey)
    private var selectedTheme = FileManagerTheme.solarizedDark.rawValue

    var body: some View {
        Form {
            Section("Theme") {
                Picker("Colors", selection: Binding(
                    get: { FileManagerTheme(rawValue: selectedTheme) ?? .solarizedDark },
                    set: { selectedTheme = $0.rawValue }
                )) {
                    ForEach(FileManagerTheme.allCases) { choice in
                        Text(choice.title).tag(choice)
                    }
                }
                HStack(spacing: 8) {
                    ForEach([theme.ink.blue, theme.ink.good, theme.ink.warn, theme.ink.bad, theme.ink.cyan, theme.ink.violet].indices, id: \.self) { index in
                        let colors = [theme.ink.blue, theme.ink.good, theme.ink.warn, theme.ink.bad, theme.ink.cyan, theme.ink.violet]
                        Circle().fill(colors[index]).frame(width: 14, height: 14)
                    }
                }
                .accessibilityHidden(true)
                Text("Applies immediately to both panes and is remembered next time.")
                    .font(.caption)
                    .foregroundStyle(theme.ink.secondary)
            }
            Section("File List") {
                Toggle("Show Hierarchical Guide Lines", isOn: $settings.showGuideLines)
                Toggle("Show Git Status Labels", isOn: $settings.gitAuraEnabled)
            }
        }
    }
}

struct SensoryPreferencesView: View {
    @ObservedObject var settings: AuraSettings
    
    var body: some View {
        Form {
            Section("Auditory Aura") {
                Toggle("Enable Sound Effects", isOn: $settings.soundEnabled)
                
                Slider(value: $settings.soundVolume, in: 0...1.0) {
                    Text("Sound Volume")
                }
                .disabled(!settings.soundEnabled)
            }
        }
    }
}
