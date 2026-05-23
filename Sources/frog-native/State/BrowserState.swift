import Foundation
import Combine

enum PaneFocus {
    case left
    case right
}

enum LayoutType: String, CaseIterable {
    case classic = "Classic List"
    case proTable = "Pro Table"
    case staircase = "Staircase Navigator"
    case verticalTree = "Vertical Tree"
}

@MainActor
class BrowserState: ObservableObject {
    @Published var left: PaneState
    @Published var right: PaneState
    @Published var focusedPane: PaneFocus = .left
    @Published var isCommandPalettePresented: Bool = false
    @Published var currentLayout: LayoutType = .verticalTree {
        didSet {
            UserDefaults.standard.set(currentLayout.rawValue, forKey: "browser.currentLayout")
        }
    }
    
    init() {
        // Restore layout
        if let savedLayout = UserDefaults.standard.string(forKey: "browser.currentLayout"),
           let layout = LayoutType(rawValue: savedLayout) {
            self.currentLayout = layout
        }

        let home = FileManager.default.homeDirectoryForCurrentUser
        let downloads = home.appendingPathComponent("Downloads")
        
        self.left = PaneState(id: "left", directory: home)
        self.right = PaneState(id: "right", directory: FileManager.default.fileExists(atPath: downloads.path) ? downloads : home)
    }
    
    func toggleFocus() {
        focusedPane = (focusedPane == .left) ? .right : .left
    }
    
    var activePane: PaneState {
        focusedPane == .left ? left : right
    }

    var inactivePane: PaneState {
        focusedPane == .left ? right : left
    }

    func teleportSyncPath() {
        SoundManager.shared.play(.teleport)
        inactivePane.currentDirectory = activePane.currentDirectory
    }

    func teleportCopySelection() {
        SoundManager.shared.play(.teleport)
        let source = activePane
        let destination = inactivePane
        
        let selectedItems = source.items.filter { source.selection.contains($0.id) }
        for item in selectedItems {
            let destURL = destination.currentDirectory.appendingPathComponent(item.name)
            try? FileManager.default.copyItem(at: item.url, to: destURL)
        }
        destination.loadContents()
    }
}
