import SwiftUI

struct AuraEditorView: View {
    @Environment(\.fileManagerPalette)
    private var theme
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
                .foregroundColor(theme.ink.blue)
                
                Spacer()
                
                HStack(spacing: 6) {
                    Image(systemName: isMarkdown && isPreviewingMarkdown ? "doc.richtext" : "pencil.line")
                        .foregroundColor(theme.ink.blue)
                    Text(isMarkdown && isPreviewingMarkdown ? "Previewing" : "Editing")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(theme.ink.blue)
                    Text(url.lastPathComponent)
                        .font(.system(size: 11, weight: .bold, design: .monospaced))
                        .foregroundColor(theme.ink.primary)
                }
                
                Spacer()

                if isMarkdown {
                    Button(isPreviewingMarkdown ? "Edit" : "Preview") {
                        isPreviewingMarkdown.toggle()
                        focusEditorIfNeeded()
                    }
                    .buttonStyle(.plain)
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(theme.ink.blue)
                    .padding(.trailing, 12)
                }
                
                if !text.isEmpty {
                    Button("Save") {
                        saveFile()
                    }
                    .buttonStyle(.plain)
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(theme.ink.blue)
                }
            }
            .padding(.horizontal, 12)
            .frame(height: 32)
            .background(theme.bg2)
            .overlay(ThemeDivider(), alignment: .bottom)
            
            if isLoading {
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                if isMarkdown && isPreviewingMarkdown {
                    MarkdownView(text: text, documentURL: url, openFile: { paneState.smartOpen($0) })
                        .id(url)
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                } else {
                    TextEditor(text: $text)
                        .font(.system(.body, design: .monospaced))
                        .scrollContentBackground(.hidden)
                        .focused($isEditorFocused)
                        .padding(8)
                        .background(theme.background)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .onAppear {
            loadFile()
        }
        .onChange(of: url) { _, _ in
            isLoading = true
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
                guard paneState.mode == .editor(url) else { return }
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
