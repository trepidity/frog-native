import SwiftUI

/// Fixed palettes from the Solarized file-manager handoff. See docs/solarized-theme.md.
enum FileManagerTheme: String, CaseIterable, Identifiable {
    case solarizedDark = "solarized-dark"
    case solarizedLight = "solarized-light"

    static let preferenceKey = "appearance.theme"
    var id: String { rawValue }
    var title: String { self == .solarizedDark ? "Solarized Dark" : "Solarized Light" }
    var colorScheme: ColorScheme { self == .solarizedDark ? .dark : .light }
    var palette: FileManagerPalette { self == .solarizedDark ? .dark : .light }
}

struct ThemeInk: Sendable {
    let primary, secondary, muted: Color
    let blue, good, bad, warn, cyan, violet: Color

    init(_ primary: UInt32, _ secondary: UInt32, _ muted: UInt32,
         _ blue: UInt32, _ good: UInt32, _ bad: UInt32, _ warn: UInt32,
         _ cyan: UInt32, _ violet: UInt32) {
        self.primary = Color(solarized: primary)
        self.secondary = Color(solarized: secondary)
        self.muted = Color(solarized: muted)
        self.blue = Color(solarized: blue)
        self.good = Color(solarized: good)
        self.bad = Color(solarized: bad)
        self.warn = Color(solarized: warn)
        self.cyan = Color(solarized: cyan)
        self.violet = Color(solarized: violet)
    }

    func name(for item: FileItem) -> Color { item.isHidden ? muted : primary }

    func kind(for item: FileItem) -> Color {
        if item.isSymbolicLink || item.isAlias { return cyan }
        if item.isPackage || ["zip", "tar", "gz", "bz2", "xz", "7z", "rar", "dmg", "iso"].contains(item.url.pathExtension.lowercased()) {
            return violet
        }
        if item.isDirectory { return blue }
        if item.isExecutable { return good }
        return item.isHidden ? muted : secondary
    }

    func git(_ status: FileItem.GitStatus) -> Color {
        switch status {
        case .added: return good
        case .modified: return warn
        case .deleted: return bad
        case .untracked, .clean: return muted
        }
    }
}

struct FileManagerPalette: Sendable {
    let bg, bg2, panel, panel2, rule, rule2, selection: Color
    let ink: ThemeInk
    let raisedInk: ThemeInk

    static let dark = FileManagerPalette(
        bg: Color(solarized: 0x002b36), bg2: Color(solarized: 0x00222b),
        panel: Color(solarized: 0x073642), panel2: Color(solarized: 0x133e4a),
        rule: Color(solarized: 0x0f4452), rule2: Color(solarized: 0x1f4751),
        selection: Color(solarized: 0x04303c),
        ink: ThemeInk(0xeee8d5, 0x93a1a1, 0x8c9b9b, 0x51a0d5, 0x90a114, 0xe8776e, 0xbb9314, 0x3ba89e, 0x9294cc),
        raisedInk: ThemeInk(0xeee8d5, 0x97a5a5, 0x97a5a5, 0x61a9d9, 0x9baa2b, 0xeb867e, 0xc29e2b, 0x4eb1a8, 0x9c9ed1)
    )
    static let light = FileManagerPalette(
        bg: Color(solarized: 0xfdf6e3), bg2: Color(solarized: 0xf6efdc),
        panel: Color(solarized: 0xeee8d5), panel2: Color(solarized: 0xe0ddcd),
        rule: Color(solarized: 0xd7d6c8), rule2: Color(solarized: 0xc5c8be),
        selection: Color(solarized: 0xf2ecd9),
        ink: ThemeInk(0x51666c, 0x4f6168, 0x54686f, 0x1e6ca4, 0x606e00, 0xc42c2a, 0x846400, 0x1e746d, 0x5d61a9),
        raisedInk: ThemeInk(0x50656b, 0x4f6168, 0x51646b, 0x1c669a, 0x5a6800, 0xb82928, 0x7b5d00, 0x1c6c66, 0x585b9f)
    )
}

private extension Color {
    init(solarized rgb: UInt32) {
        self.init(.sRGB, red: Double((rgb >> 16) & 255) / 255,
                  green: Double((rgb >> 8) & 255) / 255,
                  blue: Double(rgb & 255) / 255, opacity: 1)
    }
}

private struct FileManagerPaletteKey: EnvironmentKey {
    static let defaultValue = FileManagerPalette.dark
}

extension EnvironmentValues {
    var fileManagerPalette: FileManagerPalette {
        get { self[FileManagerPaletteKey.self] }
        set { self[FileManagerPaletteKey.self] = newValue }
    }
}

private struct FileManagerThemeModifier: ViewModifier {
    @AppStorage(FileManagerTheme.preferenceKey) private var choice = FileManagerTheme.solarizedDark.rawValue
    private var theme: FileManagerTheme { FileManagerTheme(rawValue: choice) ?? .solarizedDark }

    func body(content: Content) -> some View {
        content
            .environment(\.fileManagerPalette, theme.palette)
            .environment(\.colorScheme, theme.colorScheme)
            .preferredColorScheme(theme.colorScheme)
            .foregroundStyle(theme.palette.ink.primary)
            .tint(theme.palette.ink.blue)
            .background(theme.palette.bg)
            .onAppear { applyAppearance() }
            .onChange(of: choice) { _, _ in applyAppearance() }
    }

    private func applyAppearance() {
        NSApp.appearance = NSAppearance(named: theme.colorScheme == .dark ? .darkAqua : .aqua)
        for window in NSApp.windows {
            window.backgroundColor = NSColor(theme.palette.bg2)
        }
    }
}

extension View {
    func fileManagerTheme() -> some View { modifier(FileManagerThemeModifier()) }
}

struct ThemeDivider: View {
    @Environment(\.fileManagerPalette) private var theme
    var vertical = false
    var body: some View {
        theme.rule.frame(width: vertical ? 1 : nil, height: vertical ? nil : 1)
            .accessibilityHidden(true)
    }
}

struct SelectionBackground: View {
    @Environment(\.fileManagerPalette) private var theme
    let selected: Bool
    var focused = true
    var hovered = false

    var body: some View {
        (selected ? theme.selection : (hovered ? theme.panel2 : theme.bg))
            .overlay(alignment: .leading) {
                if selected {
                    (focused ? theme.ink.blue : theme.rule2).frame(width: 2)
                }
            }
    }
}
