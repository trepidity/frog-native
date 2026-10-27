import Foundation
import Testing
@testable import frog_native

struct MarkdownPreviewTests {
    // The generated preview document is a product output, not a parser-library test.
    // These assertions catch the old literal-line presentation and missing node dispatch.
    @Test func previewRendersDocumentStructureAndInlineFormatting() {
        let source = """
        # Project **Overview**

        A paragraph with **strong**, *emphasis*, and `inline code`.

        | Project | State |
        | :--- | ---: |
        | Example | **Ready** |

        - **Purpose:** Read a document.
          - Nested item

        > A quoted paragraph.

        ```swift
        let value = "<example>"
        ```

        Repeat this paragraph.

        - [x] Done

        Repeat this paragraph.
        """
        let html = MarkdownRenderer.render(source, documentURL: URL(fileURLWithPath: "/fixture/notes.md"))
        for fragment in ["<h1", "<strong>Overview</strong>", "<strong>Purpose:</strong>", "<em>emphasis</em>",
                         "<table>", "<th", "<td", "<strong>Ready</strong>", "<blockquote>", "<pre><code",
                         "&lt;example&gt;", "<code>inline code</code>"] {
            #expect(html.contains(fragment), "Missing rendered structure: \(fragment)")
        }
        #expect(html.components(separatedBy: "<ul>").count - 1 == 3)
        #expect(html.contains("<p><input type=\"checkbox\" disabled checked>Done</p>"))
        #expect(html.components(separatedBy: "<p>Repeat this paragraph.</p>").count - 1 == 2)
        #expect(!html.contains("| :--- | ---: |"))
    }

    @Test func previewKeepsDocumentHTMLAndUnsafeLinksInert() {
        let source = """
        <script>alert('no')</script>

        `<img src=x onerror=alert(1)>`

        [Unsafe](javascript:alert%281%29)

        [Safe](https://example.com/guide?q=one&lang=en)
        """
        let html = MarkdownRenderer.render(source, documentURL: URL(fileURLWithPath: "/fixture/notes.md"))
        #expect(!html.contains("<script>"))
        #expect(!html.contains("<img src=x"))
        #expect(!html.contains("href=\"javascript:"))
        #expect(html.contains("&lt;img"))
        #expect(html.contains("href=\"https://example.com/guide?q=one&amp;lang=en\""))
    }
}
