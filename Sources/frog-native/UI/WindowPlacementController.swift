import AppKit
import ColorSync

@MainActor
final class WindowPlacementController: NSObject, NSWindowDelegate {
    private struct Placement: Codable {
        let frame: CGRect
        let screenFrame: CGRect
        let displayID: String?
    }

    private let preferences = UserDefaults.standard
    private let key = "mainWindow.placement"

    func restoreAndTrack(_ window: NSWindow) {
        if let data = preferences.data(forKey: key),
           let saved = try? JSONDecoder().decode(Placement.self, from: data),
           saved.frame.width > 0, saved.frame.height > 0,
           let screen = NSScreen.screens.first(where: { Self.displayID($0) == saved.displayID }) ?? NSScreen.main {
            let visible = screen.visibleFrame
            let size = NSSize(
                width: min(max(saved.frame.width, window.minSize.width), visible.width),
                height: min(max(saved.frame.height, window.minSize.height), visible.height)
            )
            // Keep the offset from the same monitor's top-left corner even if
            // displays are rearranged or their resolution/scaling changes.
            let proposedX = visible.minX + saved.frame.minX - saved.screenFrame.minX
            let proposedY = visible.maxY - (saved.screenFrame.maxY - saved.frame.maxY) - size.height
            let origin = NSPoint(
                x: min(max(proposedX, visible.minX), visible.maxX - size.width),
                y: min(max(proposedY, visible.minY), visible.maxY - size.height)
            )
            window.setFrame(NSRect(origin: origin, size: size), display: false)
        } else {
            window.center()
        }
        window.delegate = self
    }

    func save(_ window: NSWindow) {
        // Preserve the normal window geometry while macOS manages full screen.
        guard !window.styleMask.contains(.fullScreen), let screen = window.screen else { return }
        let saved = Placement(frame: window.frame, screenFrame: screen.visibleFrame, displayID: Self.displayID(screen))
        guard let data = try? JSONEncoder().encode(saved) else { return }
        preferences.set(data, forKey: key)
    }

    func windowDidMove(_ notification: Notification) { saveWindow(from: notification) }
    func windowDidResize(_ notification: Notification) { saveWindow(from: notification) }
    func windowDidChangeScreen(_ notification: Notification) { saveWindow(from: notification) }
    func windowWillClose(_ notification: Notification) { saveWindow(from: notification) }

    private func saveWindow(from notification: Notification) {
        guard let window = notification.object as? NSWindow else { return }
        save(window)
    }

    private static func displayID(_ screen: NSScreen) -> String? {
        guard let number = screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber,
              let uuid = CGDisplayCreateUUIDFromDisplayID(number.uint32Value)?.takeRetainedValue() else { return nil }
        return CFUUIDCreateString(nil, uuid) as String
    }
}
