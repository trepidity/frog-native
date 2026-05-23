import AppKit
import SwiftUI
import QuickLookUI

@MainActor
class AppDelegate: NSObject, NSApplicationDelegate {
    var window: NSWindow!
    var preferencesWindow: NSWindow?
    let state = BrowserState()
    private var keyMonitor: Any?

    func applicationDidFinishLaunching(_ notification: Notification) {
        setupMenu()
        let contentView = ContentView(state: state)
        
        window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 1000, height: 700),
            styleMask: [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView],
            backing: .buffered, defer: false)
        window.center()
        window.title = "frog-native"
        window.titlebarAppearsTransparent = true
        window.titleVisibility = .hidden
        
        window.contentView = NSHostingView(rootView: contentView)
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        
        // Catch spacebar before SwiftUI List consumes it for paging.
        keyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard event.keyCode == 49 else { return event }
            guard let self else { return event }
            guard NSApp.isActive, self.window?.isKeyWindow == true else { return event }
            guard !self.state.isCommandPalettePresented else { return event }
            guard self.state.activePane.mode == .browser else { return event }

            // Leave text entry alone so the editor and command palette keep normal typing behavior.
            if self.window.firstResponder is NSTextView {
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

    private func setupMenu() {
        let mainMenu = NSMenu()
        
        // App Menu
        let appMenu = NSMenu()
        let appMenuItem = NSMenuItem()
        appMenuItem.submenu = appMenu
        appMenu.addItem(withTitle: "About frog-native", action: #selector(NSApplication.orderFrontStandardAboutPanel(_:)), keyEquivalent: "")
        appMenu.addItem(NSMenuItem.separator())
        appMenu.addItem(withTitle: "Preferences...", action: #selector(showPreferences), keyEquivalent: ",")
        appMenu.addItem(NSMenuItem.separator())
        let servicesItem = NSMenuItem(title: "Services", action: nil, keyEquivalent: "")
        let servicesMenu = NSMenu()
        servicesItem.submenu = servicesMenu
        NSApp.servicesProvider = self
        appMenu.addItem(servicesItem)
        appMenu.addItem(NSMenuItem.separator())
        appMenu.addItem(withTitle: "Hide frog-native", action: #selector(NSApplication.hide(_:)), keyEquivalent: "h")
        let hideOthersItem = appMenu.addItem(withTitle: "Hide Others", action: #selector(NSApplication.hideOtherApplications(_:)), keyEquivalent: "h")
        hideOthersItem.keyEquivalentModifierMask = [.command, .option]
        appMenu.addItem(withTitle: "Show All", action: #selector(NSApplication.unhideAllApplications(_:)), keyEquivalent: "")
        appMenu.addItem(NSMenuItem.separator())
        appMenu.addItem(withTitle: "Quit frog-native", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        mainMenu.addItem(appMenuItem)
        
        // File Menu
        let fileMenu = NSMenu(title: "File")
        let fileMenuItem = NSMenuItem()
        fileMenuItem.submenu = fileMenu
        fileMenu.addItem(withTitle: "New Folder", action: #selector(newFolder), keyEquivalent: "n")
        let trashItem = fileMenu.addItem(withTitle: "Move to Trash", action: #selector(moveToTrash), keyEquivalent: "\u{0008}")
        trashItem.keyEquivalentModifierMask = .command
        fileMenu.addItem(NSMenuItem.separator())
        fileMenu.addItem(withTitle: "Close Window", action: #selector(NSWindow.performClose(_:)), keyEquivalent: "w")
        mainMenu.addItem(fileMenuItem)

        // Edit Menu
        let editMenu = NSMenu(title: "Edit")
        let editMenuItem = NSMenuItem()
        editMenuItem.submenu = editMenu
        editMenu.addItem(withTitle: "Undo", action: Selector(("undo:")), keyEquivalent: "z")
        editMenu.addItem(withTitle: "Redo", action: Selector(("redo:")), keyEquivalent: "Z")
        editMenu.addItem(NSMenuItem.separator())
        editMenu.addItem(withTitle: "Cut", action: #selector(NSText.cut(_:)), keyEquivalent: "x")
        let copyItem = editMenu.addItem(withTitle: "Copy", action: #selector(copyToClipboard), keyEquivalent: "c")
        copyItem.keyEquivalentModifierMask = .command
        editMenu.addItem(withTitle: "Paste", action: #selector(NSText.paste(_:)), keyEquivalent: "v")
        editMenu.addItem(withTitle: "Select All", action: #selector(NSText.selectAll(_:)), keyEquivalent: "a")
        mainMenu.addItem(editMenuItem)
        
        // View Menu
        let viewMenu = NSMenu(title: "View")
        let viewMenuItem = NSMenuItem()
        viewMenuItem.submenu = viewMenu
        viewMenu.addItem(withTitle: "Command Palette...", action: #selector(toggleCommandPalette), keyEquivalent: "k")
        viewMenu.addItem(NSMenuItem.separator())
        viewMenu.addItem(withTitle: "Focus Left Pane", action: #selector(focusLeftPane), keyEquivalent: "1")
        viewMenu.addItem(withTitle: "Focus Right Pane", action: #selector(focusRightPane), keyEquivalent: "2")
        let toggleFocusItem = viewMenu.addItem(withTitle: "Toggle Focus", action: #selector(toggleFocus), keyEquivalent: "\t")
        toggleFocusItem.keyEquivalentModifierMask = [.control]
        mainMenu.addItem(viewMenuItem)
        
        // Go Menu
        let goMenu = NSMenu(title: "Go")
        let goMenuItem = NSMenuItem()
        goMenuItem.submenu = goMenu
        goMenu.addItem(withTitle: "Open", action: #selector(navigateIn), keyEquivalent: "\u{F701}") // Down Arrow
        goMenu.addItem(withTitle: "Enclosing Folder", action: #selector(navigateOut), keyEquivalent: "\u{F700}") // Up Arrow
        goMenu.addItem(NSMenuItem.separator())
        let soloItem = goMenu.addItem(withTitle: "Solo Mode", action: #selector(enterSoloMode), keyEquivalent: "\r")
        soloItem.keyEquivalentModifierMask = [.command, .shift]
        goMenu.addItem(withTitle: "Exit Solo Mode", action: #selector(exitSoloMode), keyEquivalent: "\u{001B}") // Escape
        goMenu.addItem(NSMenuItem.separator())
        goMenu.addItem(withTitle: "Back", action: #selector(navigateBack), keyEquivalent: "[")
        goMenu.addItem(withTitle: "Forward", action: #selector(navigateForward), keyEquivalent: "]")
        mainMenu.addItem(goMenuItem)
        
        // Window Menu
        let windowMenu = NSMenu(title: "Window")
        let windowMenuItem = NSMenuItem()
        windowMenuItem.submenu = windowMenu
        windowMenu.addItem(withTitle: "Minimize", action: #selector(NSWindow.performMiniaturize(_:)), keyEquivalent: "m")
        windowMenu.addItem(withTitle: "Zoom", action: #selector(NSWindow.performZoom(_:)), keyEquivalent: "")
        windowMenu.addItem(NSMenuItem.separator())
        windowMenu.addItem(withTitle: "Bring All to Front", action: #selector(NSApplication.arrangeInFront(_:)), keyEquivalent: "")
        mainMenu.addItem(windowMenuItem)
        
        // Help Menu
        let helpMenu = NSMenu(title: "Help")
        let helpMenuItem = NSMenuItem()
        helpMenuItem.submenu = helpMenu
        helpMenu.addItem(withTitle: "Frog Native User Guide", action: #selector(showHelpGuide), keyEquivalent: "?")
        mainMenu.addItem(helpMenuItem)
        
        NSApp.mainMenu = mainMenu
    }

    @objc func showHelpGuide() {
        state.activePane.mode = .helpGuide
    }

    @objc func toggleCommandPalette() {
        state.isCommandPalettePresented.toggle()
    }

    @objc func focusLeftPane() {
        state.focusedPane = .left
    }

    @objc func focusRightPane() {
        state.focusedPane = .right
    }

    @objc func toggleFocus() {
        state.toggleFocus()
    }

    @objc func navigateIn() {
        state.activePane.navigateIn()
    }

    @objc func navigateOut() {
        state.activePane.navigateOut()
    }
    
    @objc func navigateBack() {
        state.activePane.navigateBack()
    }
    
    @objc func navigateForward() {
        state.activePane.navigateForward()
    }

    @objc func enterSoloMode() {
        state.activePane.enterSoloMode()
    }

    @objc func exitSoloMode() {
        state.activePane.exitSoloMode()
    }

    @objc func newFolder() {
        state.activePane.createNewFolder()
    }

    @objc func moveToTrash() {
        state.activePane.moveSelectionToTrash()
    }

    @objc func copyToClipboard() {
        state.activePane.copySelectionToClipboardRich()
    }

    @objc func showPreferences() {
        if let existing = preferencesWindow {
            existing.makeKeyAndOrderFront(nil)
            return
        }
        
        let prefsWindow = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 450, height: 350),
            styleMask: [.titled, .closable],
            backing: .buffered, defer: false)
        prefsWindow.center()
        prefsWindow.title = "Aura Preferences"
        prefsWindow.contentView = NSHostingView(rootView: PreferencesView())
        
        self.preferencesWindow = prefsWindow
        prefsWindow.makeKeyAndOrderFront(nil)
    }

    // MARK: - Quick Look Responder Chain
    
    override func acceptsPreviewPanelControl(_ panel: QLPreviewPanel!) -> Bool {
        return true
    }
    
    override func beginPreviewPanelControl(_ panel: QLPreviewPanel!) {
        panel.delegate = QuickLookController.shared
        panel.dataSource = QuickLookController.shared
    }
    
    override func endPreviewPanelControl(_ panel: QLPreviewPanel!) {
    }
}
