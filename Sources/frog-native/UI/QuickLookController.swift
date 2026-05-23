import SwiftUI
import QuickLookUI

struct QuickLookModifier: ViewModifier {
    @Binding var url: URL?
    
    func body(content: Content) -> some View {
        content
            .onChange(of: url) { _, newURL in
                if let newURL = newURL {
                    print("QuickLook triggered for: \(newURL.path)")
                    QuickLookController.shared.show(url: newURL) {
                        self.url = nil
                    }
                } else {
                    QuickLookController.shared.hide()
                }
            }
    }
}

extension View {
    func auraQuickLookPreview(_ url: Binding<URL?>) -> some View {
        modifier(QuickLookModifier(url: url))
    }
}

@MainActor
class QuickLookController: NSObject, @preconcurrency QLPreviewPanelDataSource, @preconcurrency QLPreviewPanelDelegate {
    static let shared = QuickLookController()
    
    private var currentURL: URL?
    private var onHide: (() -> Void)?
    
    func show(url: URL, onHide: @escaping () -> Void) {
        self.currentURL = url
        self.onHide = onHide
        
        if let panel = QLPreviewPanel.shared() {
            panel.dataSource = self
            panel.delegate = self
            panel.reloadData()
            panel.makeKeyAndOrderFront(nil)
        }
    }
    
    func hide() {
        if let panel = QLPreviewPanel.shared(), panel.isVisible {
            panel.orderOut(nil)
        }
    }
    
    // MARK: - QLPreviewPanelDataSource
    
    func numberOfPreviewItems(in panel: QLPreviewPanel!) -> Int {
        return currentURL == nil ? 0 : 1
    }
    
    func previewPanel(_ panel: QLPreviewPanel!, previewItemAt index: Int) -> QLPreviewItem! {
        return currentURL as QLPreviewItem?
    }
    
    // MARK: - QLPreviewPanelDelegate
    
    func previewPanel(_ panel: QLPreviewPanel!, handle event: NSEvent!) -> Bool {
        return false
    }
    
    func previewPanel(_ panel: QLPreviewPanel!, sourceFrameOnScreenFor item: QLPreviewItem!) -> NSRect {
        return .zero
    }
}
