import Foundation
import Markdown

enum MarkdownRenderer {
    static func render(_ source: String, documentURL: URL) -> String {
        var renderer = PreviewHTML(documentURL: documentURL)
        return renderer.visit(Document(parsing: source))
    }

    static func escape(_ value: String) -> String {
        value.replacingOccurrences(of: "&", with: "&amp;")
            .replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;")
            .replacingOccurrences(of: "\"", with: "&quot;")
            .replacingOccurrences(of: "'", with: "&#39;")
    }
}

private struct PreviewHTML: MarkupVisitor {
    typealias Result = String
    let documentURL: URL
    private var headings: [String: Int] = [:]
    private var tableAlignments: [Table.ColumnAlignment?] = []
    private var tableColumn = 0
    private var inTableHead = false

    init(documentURL: URL) { self.documentURL = documentURL }

    mutating func defaultVisit(_ markup: Markup) -> String {
        var html = ""
        for child in markup.children { html += visit(child) }
        return html
    }

    mutating func wrap(_ tag: String, _ markup: Markup) -> String {
        "<\(tag)>" + defaultVisit(markup) + "</\(tag)>"
    }

    mutating func visitText(_ text: Markdown.Text) -> String { MarkdownRenderer.escape(text.string) }
    mutating func visitParagraph(_ node: Paragraph) -> String { wrap("p", node) }
    mutating func visitStrong(_ node: Strong) -> String { wrap("strong", node) }
    mutating func visitEmphasis(_ node: Emphasis) -> String { wrap("em", node) }
    mutating func visitStrikethrough(_ node: Strikethrough) -> String { wrap("del", node) }
    mutating func visitBlockQuote(_ node: BlockQuote) -> String { wrap("blockquote", node) }
    mutating func visitUnorderedList(_ node: UnorderedList) -> String { wrap("ul", node) }
    mutating func visitOrderedList(_ node: OrderedList) -> String {
        "<ol start=\"\(node.startIndex)\">" + defaultVisit(node) + "</ol>"
    }
    mutating func visitListItem(_ node: ListItem) -> String {
        let checkbox = node.checkbox.map { "<input type=\"checkbox\" disabled\($0 == .checked ? " checked" : "")>" } ?? ""
        var content = ""
        for (index, child) in node.children.enumerated() {
            if index == 0, !checkbox.isEmpty, let paragraph = child as? Paragraph {
                content += "<p>" + checkbox + defaultVisit(paragraph) + "</p>"
            } else {
                content += visit(child)
            }
        }
        return "<li\(checkbox.isEmpty ? "" : " class=\"task-item\"")>" + content + "</li>"
    }
    mutating func visitHeading(_ node: Heading) -> String {
        let slug = node.plainText
            .lowercased()
            .replacingOccurrences(of: "[^\\p{L}\\p{N}_-]+", with: "-", options: .regularExpression)
            .trimmingCharacters(in: CharacterSet(charactersIn: "-"))
        let base = slug.isEmpty ? "section" : slug
        let count = headings[base, default: 0]
        headings[base] = count + 1
        let id = base + (count == 0 ? "" : "-\(count)")
        return "<h\(node.level) id=\"\(MarkdownRenderer.escape(id))\">" + defaultVisit(node) + "</h\(node.level)>"
    }
    mutating func visitInlineCode(_ node: InlineCode) -> String {
        "<code>" + MarkdownRenderer.escape(node.code) + "</code>"
    }
    mutating func visitCodeBlock(_ node: CodeBlock) -> String {
        let label = node.language.map { "<div class=\"code-language\">\(MarkdownRenderer.escape($0))</div>" } ?? ""
        return "<div class=\"code-block\">" + label + "<pre><code>" + MarkdownRenderer.escape(node.code) + "</code></pre></div>"
    }
    mutating func visitSoftBreak(_ node: SoftBreak) -> String { "\n" }
    mutating func visitLineBreak(_ node: LineBreak) -> String { "<br>" }
    mutating func visitThematicBreak(_ node: ThematicBreak) -> String { "<hr>" }
    mutating func visitHTMLBlock(_ node: HTMLBlock) -> String { "<pre class=\"raw-html\">\(MarkdownRenderer.escape(node.rawHTML))</pre>" }
    mutating func visitInlineHTML(_ node: InlineHTML) -> String { MarkdownRenderer.escape(node.rawHTML) }

    mutating func visitLink(_ node: Link) -> String {
        let label = defaultVisit(node)
        guard let destination = node.destination, let href = safeLink(destination) else { return label }
        return "<a href=\"\(MarkdownRenderer.escape(href))\">\(label)</a>"
    }

    private func safeLink(_ destination: String) -> String? {
        if destination.hasPrefix("#") { return destination }
        guard let url = URL(string: destination, relativeTo: documentURL)?.absoluteURL,
              let scheme = url.scheme?.lowercased(), ["https", "http", "mailto", "file"].contains(scheme) else { return nil }
        if url.isFileURL {
            // WebKit blocks file: links from an in-memory document before navigation policy.
            // Route explicit clicks through the app instead of granting the document disk access.
            var components = URLComponents(url: url, resolvingAgainstBaseURL: true)
            components?.scheme = "frog-preview-file"
            return components?.url?.absoluteString
        }
        return url.absoluteString
    }

    mutating func visitImage(_ node: Image) -> String {
        let alt = MarkdownRenderer.escape(node.plainText)
        // Remote images aren't fetched merely because a local document mentions them.
        guard let source = node.source, let url = URL(string: source, relativeTo: documentURL)?.absoluteURL,
              url.isFileURL else { return "<span class=\"image-alt\">\(alt.isEmpty ? "Image" : alt)</span>" }
        let resolved = url.resolvingSymlinksInPath()
        let root = documentURL.deletingLastPathComponent().resolvingSymlinksInPath().path + "/"
        let types = ["png": "image/png", "jpg": "image/jpeg", "jpeg": "image/jpeg", "gif": "image/gif", "webp": "image/webp"]
        guard resolved.path.hasPrefix(root), let type = types[resolved.pathExtension.lowercased()],
              let size = try? resolved.resourceValues(forKeys: [.fileSizeKey]).fileSize, size <= 8_000_000,
              let data = try? Data(contentsOf: resolved), data.count <= 8_000_000 else {
            return "<span class=\"image-alt\">\(alt.isEmpty ? "Image" : alt)</span>"
        }
        return "<img src=\"data:\(type);base64,\(data.base64EncodedString())\" alt=\"\(alt)\">"
    }

    mutating func visitTable(_ node: Table) -> String {
        tableAlignments = node.columnAlignments
        return "<div class=\"table-scroll\"><table>" + defaultVisit(node) + "</table></div>"
    }
    mutating func visitTableHead(_ node: Table.Head) -> String {
        inTableHead = true
        tableColumn = 0
        let html = "<thead><tr>" + defaultVisit(node) + "</tr></thead>"
        inTableHead = false
        return html
    }
    mutating func visitTableBody(_ node: Table.Body) -> String { wrap("tbody", node) }
    mutating func visitTableRow(_ node: Table.Row) -> String {
        tableColumn = 0
        return wrap("tr", node)
    }
    mutating func visitTableCell(_ node: Table.Cell) -> String {
        let tag = inTableHead ? "th" : "td"
        let alignment = tableAlignments.indices.contains(tableColumn) ? tableAlignments[tableColumn] : nil
        tableColumn += 1
        let style = alignment.map { " style=\"text-align:\($0)\"" } ?? ""
        return "<\(tag)\(style)>" + defaultVisit(node) + "</\(tag)>"
    }
}
