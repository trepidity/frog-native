import Foundation

struct CommandAction: Identifiable {
    let id = UUID()
    let title: String
    let icon: String
    let action: () -> Void
}
