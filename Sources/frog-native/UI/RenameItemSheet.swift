import SwiftUI

struct RenameItemSheet: View {
    @ObservedObject var paneState: PaneState
    let item: FileItem
    @Environment(\.dismiss)
    private var dismiss
    @State private var name: String
    @State private var operationError: String?
    @FocusState private var nameFocused: Bool

    init(paneState: PaneState, item: FileItem) {
        self.paneState = paneState
        self.item = item
        _name = State(initialValue: item.name)
    }

    private var validationError: String? { PaneState.renameNameError(name) }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(item.isDirectory ? "Rename Folder" : "Rename File")
                .font(.headline)
            Text(item.name)
                .foregroundStyle(.secondary)
                .textSelection(.enabled)
                .lineLimit(3)
            VStack(alignment: .leading, spacing: 6) {
                Text("New name")
                TextField("Name", text: $name)
                    .textFieldStyle(.roundedBorder)
                    .accessibilityLabel("New name")
                    .focused($nameFocused)
                    .onSubmit(rename)
                if let message = operationError ?? validationError {
                    Text(message)
                        .font(.callout)
                        .foregroundStyle(.red)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            HStack {
                Spacer()
                Button("Cancel") { dismiss() }
                    .keyboardShortcut(.cancelAction)
                Button("Rename", action: rename)
                    .keyboardShortcut(.defaultAction)
                    .disabled(validationError != nil || name == item.name)
            }
        }
        .padding(24)
        .frame(width: 420)
        .onAppear { nameFocused = true }
        .onChange(of: name) { _, _ in operationError = nil }
    }

    private func rename() {
        guard validationError == nil, name != item.name else { return }
        do {
            try paneState.rename(item, to: name)
            dismiss()
        } catch let error as NSError {
            if error.domain == NSCocoaErrorDomain && error.code == NSFileWriteFileExistsError {
                operationError = "An item named “\(name)” already exists. Choose a different name."
            } else {
                operationError = error.localizedDescription
            }
        }
    }
}
