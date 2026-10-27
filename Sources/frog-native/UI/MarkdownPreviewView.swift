import SwiftUI
import WebKit

struct MarkdownView: View {
    @Environment(\.fileManagerPalette)
    private var theme
    let text: String
    let documentURL: URL
    let openFile: (URL) -> Void
    @State private var bodyHTML: String?

    var body: some View {
        Group {
            if let bodyHTML {
                MarkdownWebView(html: MarkdownPage.html(body: bodyHTML, palette: theme), openFile: openFile)
            } else {
                ProgressView().frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .background(theme.bg)
        .task(id: text) {
            let source = text, url = documentURL
            let work = Task.detached(priority: .userInitiated) { MarkdownRenderer.render(source, documentURL: url) }
            let result = await withTaskCancellationHandler { await work.value } onCancel: { work.cancel() }
            guard !Task.isCancelled else { return }
            bodyHTML = result
        }
    }
}

@MainActor
enum MarkdownPage {
    private static func hex(_ color: Color) -> String {
        guard let rgb = NSColor(color).usingColorSpace(.sRGB) else { return "#000000" }
        return String(
            format: "#%02x%02x%02x",
            Int((rgb.redComponent * 255).rounded()),
            Int((rgb.greenComponent * 255).rounded()),
            Int((rgb.blueComponent * 255).rounded())
        )
    }

    static func html(body: String, palette: FileManagerPalette) -> String {
        return """
        <!doctype html><html lang="en"><head><meta charset="utf-8">
        <meta name="viewport" content="width=device-width, initial-scale=1">
        <meta http-equiv="Content-Security-Policy"
          content="default-src 'none'; style-src 'unsafe-inline'; img-src data:; script-src 'none'; base-uri 'none'; form-action 'none'">
        <style>
        :root { --bg:\(hex(palette.bg)); --panel:\(hex(palette.panel)); --raised:\(hex(palette.panel2));
          --text:\(hex(palette.ink.primary)); --muted:\(hex(palette.ink.secondary)); --link:\(hex(palette.ink.blue));
          --accent:\(hex(palette.ink.cyan)); --rule:\(hex(palette.rule2)); --selection:\(hex(palette.panel2)); }
        * { box-sizing:border-box; }
        html { background:var(--bg); color:var(--text); -webkit-text-size-adjust:100%; }
        body { margin:0; font:15px/1.65 -apple-system,BlinkMacSystemFont,"Helvetica Neue",sans-serif;
          overflow-wrap:anywhere; -webkit-font-smoothing:antialiased; }
        article { max-width:860px; padding:32px clamp(20px,4vw,48px) 72px; margin:0 auto; }
        article > :first-child { margin-top:0; }
        p { margin:0 0 1.1em; }
        h1,h2,h3,h4,h5,h6 { line-height:1.25; font-weight:650; letter-spacing:-.02em; scroll-margin-top:24px; }
        h1 { font-size:30px; margin:0 0 24px; padding-bottom:16px; border-bottom:1px solid var(--rule); }
        h2 { font-size:23px; margin:36px 0 16px; padding-bottom:10px; border-bottom:1px solid var(--rule); }
        h3 { font-size:19px; margin:28px 0 12px; }
        h4 { font-size:16px; margin:24px 0 10px; }
        h5,h6 { font-size:14px; margin:20px 0 8px; color:var(--muted); }
        strong { font-weight:650; }
        a { color:var(--link); text-decoration:underline; text-underline-offset:3px; }
        a:hover { text-decoration-thickness:2px; }
        a:focus-visible { outline:2px solid var(--link); outline-offset:3px; border-radius:2px; }
        ul,ol { padding-left:1.6em; margin:0 0 1.2em; }
        li { padding-left:.2em; margin:.35em 0; }
        li::marker { color:var(--link); }
        li > p { margin:.25em 0; }
        li > ul,li > ol { margin:.4em 0 .7em; }
        input[type=checkbox] { accent-color:var(--accent); margin-right:.5em; }
        .task-item { list-style:none; }
        .task-item input { margin-left:-1.4em; }
        blockquote { margin:20px 0; padding:12px 18px; border-left:3px solid var(--accent);
          background:var(--panel); border-radius:0 6px 6px 0; }
        blockquote > :last-child { margin-bottom:0; }
        code,pre { font-family:ui-monospace,"SFMono-Regular",Menlo,monospace; font-size:12.5px; }
        :not(pre) > code { background:var(--panel); color:var(--accent); padding:2px 5px; border-radius:4px; }
        .code-block { margin:20px 0; border:1px solid var(--rule); border-radius:8px; overflow:hidden; background:var(--panel); }
        .code-language { padding:6px 16px; font-size:11px; font-weight:600; color:var(--muted); border-bottom:1px solid var(--rule); }
        pre { margin:0; padding:16px; overflow-x:auto; line-height:1.6; tab-size:4; white-space:pre; }
        .raw-html { background:var(--panel); margin:16px 0; border-radius:6px; }
        .table-scroll { max-width:100%; overflow-x:auto; margin:24px 0; border:1px solid var(--rule); border-radius:8px; }
        table { width:100%; border-collapse:collapse; font-size:13px; line-height:1.5; }
        th,td { padding:10px 14px; text-align:left; vertical-align:top; border-bottom:1px solid var(--rule); min-width:90px; }
        th { font-weight:650; background:var(--panel); white-space:nowrap; }
        tbody tr:last-child td { border-bottom:0; }
        tbody tr:nth-child(even) { background:var(--panel); }
        td > p { margin:0; }
        hr { border:0; height:1px; background:var(--rule); margin:32px 0; }
        img { max-width:100%; height:auto; border-radius:6px; }
        .image-alt { display:inline-block; color:var(--muted); border:1px dashed var(--rule); padding:8px 12px; border-radius:6px; }
        ::selection { background:var(--selection); }
        @media (max-width:480px) { body { font-size:14px; } article { padding:24px 20px 48px; } h1 { font-size:26px; } }
        </style></head><body><article>\(body)</article></body></html>
        """
    }
}

private struct MarkdownWebView: NSViewRepresentable {
    let html: String
    let openFile: (URL) -> Void

    func makeCoordinator() -> Coordinator { Coordinator(openFile: openFile) }

    func makeNSView(context: Context) -> WKWebView {
        let configuration = WKWebViewConfiguration()
        configuration.websiteDataStore = .nonPersistent()
        configuration.defaultWebpagePreferences.allowsContentJavaScript = false
        let view = WKWebView(frame: .zero, configuration: configuration)
        view.navigationDelegate = context.coordinator
        view.allowsBackForwardNavigationGestures = false
        return view
    }

    func updateNSView(_ view: WKWebView, context: Context) {
        context.coordinator.openFile = openFile
        guard context.coordinator.html != html else { return }
        context.coordinator.html = html
        view.loadHTMLString(html, baseURL: nil)
    }

    @MainActor
    final class Coordinator: NSObject, WKNavigationDelegate {
        var html = ""
        var openFile: (URL) -> Void
        init(openFile: @escaping (URL) -> Void) { self.openFile = openFile }

        func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction) async -> WKNavigationActionPolicy {
            guard let url = navigationAction.request.url else { return .cancel }
            if url.scheme == "about" { return .allow }
            guard navigationAction.navigationType == .linkActivated else { return .cancel }
            if url.scheme == "frog-preview-file" {
                var components = URLComponents(url: url, resolvingAgainstBaseURL: true)
                components?.scheme = "file"
                if let fileURL = components?.url { openFile(fileURL) }
            } else if ["https", "http", "mailto"].contains(url.scheme?.lowercased() ?? "") { NSWorkspace.shared.open(url) }
            return .cancel
        }
    }
}
