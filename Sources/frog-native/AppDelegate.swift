import AppKit
import SwiftUI
import QuickLookUI

@MainActor
class AppDelegate: NSObject, NSApplicationDelegate {
    var window: NSWindow?
    var preferencesWindow: NSWindow?
    let state = BrowserState()
    private var keyMonitor: Any?

    func applicationDidFinishLaunching(_ notification: Notification) {
        setupMenu()
        let contentView = ContentView(state: state)

        let mainWindow = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 1000, height: 700),
            styleMask: [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        mainWindow.center()
        mainWindow.title = "frog-native"
        mainWindow.titlebarAppearsTransparent = true
        mainWindow.titleVisibility = .hidden
        mainWindow.contentView = NSHostingView(rootView: contentView)
        mainWindow.makeKeyAndOrderFront(nil)
        window = mainWindow

        NSApp.activate(ignoringOtherApps: true)
        installSpacebarMonitor()
    }

    private func installSpacebarMonitor() {
        keyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard event.keyCode == 49 else { return event }
            guard let self else { return event }
            guard NSApp.isActive, self.window?.isKeyWindow == true else { return event }
            guard !self.state.isCommandPalettePresented else { return event }
            guard self.state.activePane.mode == .browser else { return event }
            if self.window?.firstResponder is NSTextView {
                return event
            }
            self.state.activePane.handleSpacebar()
            return nil
        }
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        return true
    }

    func applicationWillTerminate(_ notification: Notification) {
        if let keyMonitor {
            NSEvent.removeMonitor(keyMonitor)
        }
    }

    @objc
    func showHelpGuide() {
        state.activePane.mode = .helpGuide
    }

    @objc
    func toggleCommandPalette() {
        state.isCommandPalettePresented.toggle()
    }

    @objc
    func focusLeftPane() {
        state.focusedPane = .left
    }

    @objc
    func focusRightPane() {
        state.focusedPane = .right
    }

    @objc
    func toggleFocus() {
        state.toggleFocus()
    }

    @objc
    func navigateIn() {
        state.activePane.navigateIn()
    }

    @objc
    func navigateOut() {
        state.activePane.navigateOut()
    }

    @objc
    func navigateBack() {
        state.activePane.navigateBack()
    }

    @objc
    func navigateForward() {
        state.activePane.navigateForward()
    }

    @objc
    func enterSoloMode() {
        state.activePane.enterSoloMode()
    }

    @objc
    func exitSoloMode() {
        state.activePane.exitSoloMode()
    }

    @objc
    func newFolder() {
        state.activePane.createNewFolder()
    }

    @objc
    func moveToTrash() {
        state.activePane.moveSelectionToTrash()
    }

    @objc
    func copyToClipboard() {
        state.activePane.copySelectionToClipboardRich()
    }

    @objc
    func showPreferences() {
        if let existing = preferencesWindow {
            existing.makeKeyAndOrderFront(nil)
            return
        }

        let prefsWindow = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 450, height: 350),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        prefsWindow.center()
        prefsWindow.title = "Aura Preferences"
        prefsWindow.contentView = NSHostingView(rootView: PreferencesView())

        self.preferencesWindow = prefsWindow
        prefsWindow.makeKeyAndOrderFront(nil)
    }

    // MARK: - Quick Look Responder Chain

    // swiftlint:disable implicitly_unwrapped_optional
    override func acceptsPreviewPanelControl(_ panel: QLPreviewPanel!) -> Bool {
        return true
    }

    override func beginPreviewPanelControl(_ panel: QLPreviewPanel!) {
        panel.delegate = QuickLookController.shared
        panel.dataSource = QuickLookController.shared
    }

    override func endPreviewPanelControl(_ panel: QLPreviewPanel!) {
    }
    // swiftlint:enable implicitly_unwrapped_optional
}
