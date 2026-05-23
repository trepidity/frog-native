import AppKit

extension AppDelegate {
    func setupMenu() {
        let mainMenu = NSMenu()
        mainMenu.addItem(buildAppMenuItem())
        mainMenu.addItem(buildFileMenuItem())
        mainMenu.addItem(buildEditMenuItem())
        mainMenu.addItem(buildViewMenuItem())
        mainMenu.addItem(buildGoMenuItem())
        mainMenu.addItem(buildWindowMenuItem())
        mainMenu.addItem(buildHelpMenuItem())
        NSApp.mainMenu = mainMenu
    }

    private func buildAppMenuItem() -> NSMenuItem {
        let appMenu = NSMenu()
        appMenu.addItem(
            withTitle: "About frog-native",
            action: #selector(NSApplication.orderFrontStandardAboutPanel(_:)),
            keyEquivalent: ""
        )
        appMenu.addItem(NSMenuItem.separator())
        appMenu.addItem(
            withTitle: "Preferences...",
            action: #selector(showPreferences),
            keyEquivalent: ","
        )
        appMenu.addItem(NSMenuItem.separator())
        let servicesItem = NSMenuItem(title: "Services", action: nil, keyEquivalent: "")
        servicesItem.submenu = NSMenu()
        NSApp.servicesProvider = self
        appMenu.addItem(servicesItem)
        appMenu.addItem(NSMenuItem.separator())
        appMenu.addItem(
            withTitle: "Hide frog-native",
            action: #selector(NSApplication.hide(_:)),
            keyEquivalent: "h"
        )
        let hideOthersItem = appMenu.addItem(
            withTitle: "Hide Others",
            action: #selector(NSApplication.hideOtherApplications(_:)),
            keyEquivalent: "h"
        )
        hideOthersItem.keyEquivalentModifierMask = [.command, .option]
        appMenu.addItem(
            withTitle: "Show All",
            action: #selector(NSApplication.unhideAllApplications(_:)),
            keyEquivalent: ""
        )
        appMenu.addItem(NSMenuItem.separator())
        appMenu.addItem(
            withTitle: "Quit frog-native",
            action: #selector(NSApplication.terminate(_:)),
            keyEquivalent: "q"
        )
        let appMenuItem = NSMenuItem()
        appMenuItem.submenu = appMenu
        return appMenuItem
    }

    private func buildFileMenuItem() -> NSMenuItem {
        let fileMenu = NSMenu(title: "File")
        fileMenu.addItem(withTitle: "New Folder", action: #selector(newFolder), keyEquivalent: "n")
        let trashItem = fileMenu.addItem(
            withTitle: "Move to Trash",
            action: #selector(moveToTrash),
            keyEquivalent: "\u{0008}"
        )
        trashItem.keyEquivalentModifierMask = .command
        fileMenu.addItem(NSMenuItem.separator())
        fileMenu.addItem(
            withTitle: "Close Window",
            action: #selector(NSWindow.performClose(_:)),
            keyEquivalent: "w"
        )
        let fileMenuItem = NSMenuItem()
        fileMenuItem.submenu = fileMenu
        return fileMenuItem
    }

    private func buildEditMenuItem() -> NSMenuItem {
        let editMenu = NSMenu(title: "Edit")
        editMenu.addItem(withTitle: "Undo", action: Selector(("undo:")), keyEquivalent: "z")
        editMenu.addItem(withTitle: "Redo", action: Selector(("redo:")), keyEquivalent: "Z")
        editMenu.addItem(NSMenuItem.separator())
        editMenu.addItem(withTitle: "Cut", action: #selector(NSText.cut(_:)), keyEquivalent: "x")
        let copyItem = editMenu.addItem(
            withTitle: "Copy",
            action: #selector(copyToClipboard),
            keyEquivalent: "c"
        )
        copyItem.keyEquivalentModifierMask = .command
        editMenu.addItem(withTitle: "Paste", action: #selector(NSText.paste(_:)), keyEquivalent: "v")
        editMenu.addItem(
            withTitle: "Select All",
            action: #selector(NSText.selectAll(_:)),
            keyEquivalent: "a"
        )
        let editMenuItem = NSMenuItem()
        editMenuItem.submenu = editMenu
        return editMenuItem
    }

    private func buildViewMenuItem() -> NSMenuItem {
        let viewMenu = NSMenu(title: "View")
        viewMenu.addItem(
            withTitle: "Command Palette...",
            action: #selector(toggleCommandPalette),
            keyEquivalent: "k"
        )
        viewMenu.addItem(NSMenuItem.separator())
        viewMenu.addItem(
            withTitle: "Focus Left Pane",
            action: #selector(focusLeftPane),
            keyEquivalent: "1"
        )
        viewMenu.addItem(
            withTitle: "Focus Right Pane",
            action: #selector(focusRightPane),
            keyEquivalent: "2"
        )
        let toggleFocusItem = viewMenu.addItem(
            withTitle: "Toggle Focus",
            action: #selector(toggleFocus),
            keyEquivalent: "\t"
        )
        toggleFocusItem.keyEquivalentModifierMask = [.control]
        let viewMenuItem = NSMenuItem()
        viewMenuItem.submenu = viewMenu
        return viewMenuItem
    }

    private func buildGoMenuItem() -> NSMenuItem {
        let goMenu = NSMenu(title: "Go")
        goMenu.addItem(withTitle: "Open", action: #selector(navigateIn), keyEquivalent: "\u{F701}")
        goMenu.addItem(
            withTitle: "Enclosing Folder",
            action: #selector(navigateOut),
            keyEquivalent: "\u{F700}"
        )
        goMenu.addItem(NSMenuItem.separator())
        let soloItem = goMenu.addItem(
            withTitle: "Solo Mode",
            action: #selector(enterSoloMode),
            keyEquivalent: "\r"
        )
        soloItem.keyEquivalentModifierMask = [.command, .shift]
        goMenu.addItem(
            withTitle: "Exit Solo Mode",
            action: #selector(exitSoloMode),
            keyEquivalent: "\u{001B}"
        )
        goMenu.addItem(NSMenuItem.separator())
        goMenu.addItem(withTitle: "Back", action: #selector(navigateBack), keyEquivalent: "[")
        goMenu.addItem(withTitle: "Forward", action: #selector(navigateForward), keyEquivalent: "]")
        let goMenuItem = NSMenuItem()
        goMenuItem.submenu = goMenu
        return goMenuItem
    }

    private func buildWindowMenuItem() -> NSMenuItem {
        let windowMenu = NSMenu(title: "Window")
        windowMenu.addItem(
            withTitle: "Minimize",
            action: #selector(NSWindow.performMiniaturize(_:)),
            keyEquivalent: "m"
        )
        windowMenu.addItem(
            withTitle: "Zoom",
            action: #selector(NSWindow.performZoom(_:)),
            keyEquivalent: ""
        )
        windowMenu.addItem(NSMenuItem.separator())
        windowMenu.addItem(
            withTitle: "Bring All to Front",
            action: #selector(NSApplication.arrangeInFront(_:)),
            keyEquivalent: ""
        )
        let windowMenuItem = NSMenuItem()
        windowMenuItem.submenu = windowMenu
        return windowMenuItem
    }

    private func buildHelpMenuItem() -> NSMenuItem {
        let helpMenu = NSMenu(title: "Help")
        helpMenu.addItem(
            withTitle: "Frog Native User Guide",
            action: #selector(showHelpGuide),
            keyEquivalent: "?"
        )
        let helpMenuItem = NSMenuItem()
        helpMenuItem.submenu = helpMenu
        return helpMenuItem
    }
}
