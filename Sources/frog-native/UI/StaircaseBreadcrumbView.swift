import SwiftUI

struct StaircaseBreadcrumbView: View {
    let currentDirectory: URL
    let onNavigate: (URL) -> Void
    
    var body: some View {
        let components = pathComponents(for: currentDirectory)
        
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: -12) { // Negative spacing for the "staircase" overlap
                ForEach(0..<components.count, id: \.self) { index in
                    let item = components[index]
                    let isLast = index == components.count - 1
                    
                    StaircaseStep(
                        title: item.name,
                        depth: index,
                        isLast: isLast,
                        action: { onNavigate(item.url) }
                    )
                    .zIndex(Double(index)) // Ensure later steps are on top
                }
            }
            .padding(.vertical, 8)
            .padding(.horizontal, 16)
        }
        .background(Color(NSColor.controlBackgroundColor).opacity(0.3))
        .frame(height: 60)
    }
    
    private func pathComponents(for url: URL) -> [(name: String, url: URL)] {
        var result: [(name: String, url: URL)] = []
        var current = url
        
        while current.path != "/" {
            result.insert((current.lastPathComponent, current), at: 0)
            current = current.deletingLastPathComponent()
        }
        result.insert(("Root", URL(fileURLWithPath: "/")), at: 0)
        return result
    }
}

struct StaircaseStep: View {
    let title: String
    let depth: Int
    let isLast: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 4) {
                Image(systemName: depth == 0 ? "desktopcomputer" : "folder")
                    .font(.system(size: 10))
                Text(title)
                    .font(.system(size: 11, weight: isLast ? .bold : .regular))
            }
            .padding(.vertical, 6)
            .padding(.horizontal, 12)
            .padding(.leading, depth > 0 ? 12 : 0) // Offset for overlap
            .background(
                StaircaseShape()
                    .fill(isLast ? Color.accentColor : Color(NSColor.controlColor))
                    .shadow(radius: 2, x: 2, y: 0)
            )
            .foregroundColor(isLast ? .white : .primary)
        }
        .buttonStyle(.plain)
    }
}

struct StaircaseShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let slant: CGFloat = 12
        
        path.move(to: CGPoint(x: 0, y: 0))
        path.addLine(to: CGPoint(x: rect.width - slant, y: 0))
        path.addLine(to: CGPoint(x: rect.width, y: rect.height / 2))
        path.addLine(to: CGPoint(x: rect.width - slant, y: rect.height))
        path.addLine(to: CGPoint(x: 0, y: rect.height))
        path.addLine(to: CGPoint(x: slant, y: rect.height / 2))
        path.closeSubpath()
        
        return path
    }
}
