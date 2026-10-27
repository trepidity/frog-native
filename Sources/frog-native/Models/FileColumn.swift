import Foundation

enum FileColumn: String, CaseIterable, Identifiable {
    case name, created, modified, dimensions, kind, size
    var id: String { rawValue }
    var title: String { self == .kind ? "Type" : rawValue.capitalized }
}
