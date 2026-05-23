import SwiftUI

struct AuraEditorView: View {
    let url: URL
    @ObservedObject var paneState: PaneState
    @State private var text: String = ""
    @State private var isLoading: Bool = true
    @State private var isPreviewingMarkdown: Bool = false
    @FocusState private var isEditorFocused: Bool
    
    var body: some View {
        VStack(spacing: 0) {
            // Editor Toolbar
            HStack {
                Button(action: { 
                    withAnimation(.spring(response: 0.3)) {
                        paneState.closeEditor()
                    }
                }) {
                    HStack(spacing: 4) {
                        Image(systemName: "arrow.left")
                        Text("Back to Tree")
                    }
                }
                .buttonStyle(.plain)
                .font(.system(size: 10, weight: .bold))
                .foregroundColor(.accentColor)
                
                Spacer()
                
                HStack(spacing: 6) {
                    Image(systemName: isMarkdown && isPreviewingMarkdown ? "doc.richtext" : "pencil.line")
                        .foregroundColor(.accentColor)
                    Text(isMarkdown && isPreviewingMarkdown ? "Previewing" : "Editing")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(.accentColor)
                    Text(url.lastPathComponent)
                        .font(.system(size: 11, weight: .bold, design: .monospaced))
                        .foregroundColor(.primary)
                }
                
                Spacer()

                if isMarkdown {
                    Button(isPreviewingMarkdown ? "Edit" : "Preview") {
                        isPreviewingMarkdown.toggle()
                        focusEditorIfNeeded()
                    }
                    .buttonStyle(.plain)
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(.accentColor)
                    .padding(.trailing, 12)
                }
                
                if !text.isEmpty {
                    Button("Save") {
                        saveFile()
                    }
                    .buttonStyle(.plain)
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(.accentColor)
                }
            }
            .padding(.horizontal, 12)
            .frame(height: 32)
            .background(VisualEffectView(material: .headerView, blendingMode: .withinWindow))
            .overlay(Divider(), alignment: .bottom)
            
            if isLoading {
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                if isMarkdown && isPreviewingMarkdown {
                    MarkdownView(text: text)
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                } else {
                    TextEditor(text: $text)
                        .font(.system(.body, design: .monospaced))
                        .scrollContentBackground(.hidden)
                        .focused($isEditorFocused)
                        .padding(8)
                        .background(VisualEffectView(material: .sidebar, blendingMode: .withinWindow))
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .onAppear {
            loadFile()
        }
        .onChange(of: isLoading) { _, newValue in
            if !newValue {
                focusEditorIfNeeded()
            }
        }
        .onChange(of: paneState.mode) { _, newMode in
            if case .editor(let activeURL) = newMode, activeURL == url {
                focusEditorIfNeeded()
            }
        }
    }
    
    private var isMarkdown: Bool {
        url.pathExtension.lowercased() == "md"
    }
    
    private func loadFile() {
        DispatchQueue.global(qos: .userInitiated).async {
            let content = (try? String(contentsOf: url)) ?? ""
            DispatchQueue.main.async {
                self.text = content
                self.isLoading = false
            }
        }
    }

    private func focusEditorIfNeeded() {
        guard !isLoading, !isMarkdown || !isPreviewingMarkdown else { return }

        DispatchQueue.main.async {
            isEditorFocused = true
        }
    }
    
    private func saveFile() {
        try? text.write(to: url, atomically: true, encoding: .utf8)
    }
}

struct MarkdownView: View {
    let text: String
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                // Simple Markdown-ish preview for the prototype
                ForEach(text.components(separatedBy: "\n"), id: \.self) { line in
                    if line.hasPrefix("#") {
                        Text(line.replacingOccurrences(of: "#", with: ""))
                            .font(.title2)
                            .bold()
                    } else if line.hasPrefix("-") || line.hasPrefix("*") {
                        HStack(alignment: .top) {
                            Text("•")
                            Text(line.dropFirst().trimmingCharacters(in: .whitespaces))
                        }
                    } else {
                        Text(line)
                    }
                }
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .background(VisualEffectView(material: .sidebar, blendingMode: .withinWindow))
    }
}
