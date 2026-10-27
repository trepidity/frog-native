import SwiftUI

struct GitStatusBadge: View {
    let status: FileItem.GitStatus
    let ink: ThemeInk

    private var label: String? {
        switch status {
        case .clean: return nil
        case .added: return "Added"
        case .modified: return "Modified"
        case .deleted: return "Deleted"
        case .untracked: return "Untracked"
        }
    }

    var body: some View {
        if let label {
            Text(label).font(.system(size: 9, weight: .medium))
                .foregroundStyle(ink.git(status))
                .lineLimit(1)
                .help("Git: \(label)")
        }
    }
}
