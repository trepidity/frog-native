import AppKit
import SwiftUI

/// The asset kit and runtime icon share the same generated SVG artwork.
struct AuraIconView: View {
    var size: CGFloat = 512

    var body: some View {
        if let image = AuraIconRenderer.makeApplicationIcon(size: size) {
            Image(nsImage: image)
                .resizable()
                .interpolation(.high)
                .frame(width: size, height: size)
                .accessibilityLabel("Frog Native")
        }
    }
}

@MainActor
enum AuraIconRenderer {
    static func makeApplicationIcon(size: CGFloat = 512) -> NSImage? {
        let image = NSImage(size: NSSize(width: size, height: size))
        for pixels in [16, 32, 64, 128, 256, 512, 1024] {
            guard let url = Bundle.module.url(forResource: "app-\(pixels)", withExtension: "png", subdirectory: "Brand"),
                  let data = try? Data(contentsOf: url),
                  let representation = NSBitmapImageRep(data: data) else { return nil }
            image.addRepresentation(representation)
        }
        return image
    }

    static func makeWindowIcon(size: CGFloat = 128) -> NSImage? {
        makeApplicationIcon(size: size)
    }

    static func renderPNGData(pixelSize: Int) -> Data? {
        if let url = Bundle.module.url(forResource: "app-\(pixelSize)", withExtension: "png", subdirectory: "Brand") {
            return try? Data(contentsOf: url)
        }
        let name = pixelSize <= 32 ? "app-icon-dark-small" : "app-icon-dark"
        guard pixelSize > 0, pixelSize <= 8192,
              let sourceURL = Bundle.module.url(forResource: name, withExtension: "svg", subdirectory: "Brand"),
              let source = NSImage(contentsOf: sourceURL),
              let bitmap = NSBitmapImageRep(
                  bitmapDataPlanes: nil,
                  pixelsWide: pixelSize,
                  pixelsHigh: pixelSize,
                  bitsPerSample: 8,
                  samplesPerPixel: 4,
                  hasAlpha: true,
                  isPlanar: false,
                  colorSpaceName: .deviceRGB,
                  bytesPerRow: pixelSize * 4,
                  bitsPerPixel: 32
              ),
              let context = NSGraphicsContext(bitmapImageRep: bitmap) else { return nil }
        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = context
        source.draw(
            in: NSRect(x: 0, y: 0, width: pixelSize, height: pixelSize),
            from: .zero,
            operation: .copy,
            fraction: 1
        )
        context.flushGraphics()
        NSGraphicsContext.restoreGraphicsState()
        return bitmap.representation(using: .png, properties: [:])
    }
}
