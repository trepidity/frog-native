import AppKit
import SwiftUI

struct AuraIconView: View {
    var size: CGFloat = 512
    
    var body: some View {
        ZStack {
            // macOS Squircle Base
            RoundedRectangle(cornerRadius: size * 0.22, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [Color(red: 0.1, green: 0.2, blue: 0.15), Color(red: 0.05, green: 0.05, blue: 0.1)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .shadow(radius: size * 0.05, y: size * 0.02)
            
            // The "Aura" Glow
            Circle()
                .fill(
                    RadialGradient(
                        colors: [Color.green.opacity(0.3), Color.clear],
                        center: .center,
                        startRadius: 0,
                        endRadius: size * 0.4
                    )
                )
                .blur(radius: size * 0.05)
            
            // Glassmorphic Layer
            RoundedRectangle(cornerRadius: size * 0.22, style: .continuous)
                .stroke(Color.white.opacity(0.1), lineWidth: size * 0.005)
                .background(
                    RoundedRectangle(cornerRadius: size * 0.22, style: .continuous)
                        .fill(Color.white.opacity(0.02))
                )
            
            // The "Staircase Frog" (Hero Element)
            VStack(spacing: size * 0.04) {
                // Three descending bars representing the hierarchy and the dual pane
                HStack(alignment: .bottom, spacing: size * 0.03) {
                    // Left segment (Head/Primary)
                    VStack(spacing: size * 0.02) {
                        Capsule()
                            .fill(Color.accentColor)
                            .frame(width: size * 0.12, height: size * 0.35)
                        Circle()
                            .fill(Color.accentColor)
                            .frame(width: size * 0.12)
                    }
                    
                    // Middle segment (Stair 1)
                    Capsule()
                        .fill(Color.accentColor.opacity(0.7))
                        .frame(width: size * 0.12, height: size * 0.25)
                    
                    // Right segment (Stair 2)
                    Capsule()
                        .fill(Color.accentColor.opacity(0.4))
                        .frame(width: size * 0.12, height: size * 0.15)
                }
                .offset(y: size * 0.05)
                
                // The "Base" (Grounding the stairs)
                Capsule()
                    .fill(
                        LinearGradient(colors: [.accentColor, .clear], startPoint: .leading, endPoint: .trailing)
                    )
                    .frame(width: size * 0.5, height: size * 0.02)
                    .opacity(0.3)
            }
            .rotationEffect(.degrees(-5)) // Dynamic "climbing" angle
            
            // The "Sparkle" (Active Aura)
            Image(systemName: "sparkle")
                .font(.system(size: size * 0.15, weight: .bold))
                .foregroundColor(.white)
                .shadow(color: .accentColor, radius: size * 0.02)
                .offset(x: size * 0.25, y: -size * 0.25)
        }
        .frame(width: size, height: size)
    }
}

@MainActor
enum AuraIconRenderer {
    static func makeApplicationIcon(size: CGFloat = 512) -> NSImage? {
        renderImage(size: size)
    }

    static func makeWindowIcon(size: CGFloat = 128) -> NSImage? {
        renderImage(size: size)
    }

    private static func renderImage(size: CGFloat) -> NSImage? {
        guard let cgImage = renderCGImage(pixelSize: Int(size.rounded())) else {
            return nil
        }
        return NSImage(cgImage: cgImage, size: NSSize(width: size, height: size))
    }

    static func renderPNGData(pixelSize: Int) -> Data? {
        guard let cgImage = renderCGImage(pixelSize: pixelSize) else {
            return nil
        }
        let bitmap = NSBitmapImageRep(cgImage: cgImage)
        return bitmap.representation(using: .png, properties: [:])
    }

    private static func renderCGImage(pixelSize: Int) -> CGImage? {
        let side = CGFloat(pixelSize)
        let renderer = ImageRenderer(
            content: AuraIconView(size: side)
                .environment(\.colorScheme, .dark)
        )
        renderer.scale = 1
        renderer.proposedSize = ProposedViewSize(width: side, height: side)
        return renderer.cgImage
    }
}

// Preview wrapper for checking the icon in the project
struct AuraIconPreview: View {
    var body: some View {
        VStack(spacing: 40) {
            Text("Aura Application Icon")
                .font(.title)
                .bold()
            
            HStack(spacing: 60) {
                VStack {
                    AuraIconView(size: 256)
                    Text("Large (Dock)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                VStack {
                    AuraIconView(size: 64)
                    Text("Small (Finder)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            Text("Design Philosophy: The 'Staircase' segments represent the hierarchical tree, while the 'Sparkle' and deep gradient anchor it to the Aura theme.")
                .font(.callout)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
        }
        .padding(60)
        .background(Color(NSColor.windowBackgroundColor))
    }
}
