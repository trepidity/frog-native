import SwiftUI

struct ColumnVisibilityMenu: View {
    @ObservedObject var paneState: PaneState
    var body: some View {
        ForEach(FileColumn.allCases) { column in
            Toggle(column.title, isOn: Binding(
                get: { paneState.displayedColumns.contains(column) },
                set: { paneState.setColumnVisible(column, $0) }
            ))
            .disabled(column == .name)
        }
        Divider()
        Button("Restore Default Columns") { paneState.resetColumns() }
    }
}

extension FileColumn {
    var treeWidth: CGFloat { self == .size ? 96 : 128 }
}

struct FileMetadataCell: View {
    let column: FileColumn
    let item: FileItem

    private static let friendlyDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        formatter.doesRelativeDateFormatting = true
        return formatter
    }()

    private func dateLabel(_ date: Date) -> some View {
        Text(date, formatter: Self.friendlyDateFormatter)
            .help(date.formatted(date: .complete, time: .complete))
    }

    var body: some View {
        Group {
            switch column {
            case .created: dateLabel(item.creationDate)
            case .modified: dateLabel(item.modificationDate)
            case .dimensions: Text(item.dimensions ?? "--")
            case .kind: Text(item.fileTypeDescription ?? "--")
            case .size:
                Text(item.isDirectory ? "--" : ByteCountFormatter.string(fromByteCount: item.size, countStyle: .file))
                    .monospaced()
            case .name: Text(item.name)
            }
        }
        .lineLimit(1)
        .frame(maxWidth: .infinity, alignment: column == .size ? .trailing : .leading)
    }
}
