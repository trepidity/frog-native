import AppKit

// Usage: render-svg input.svg output.png pixel-width
let arguments = CommandLine.arguments
guard arguments.count == 4, let width = Int(arguments[3]), width > 0, width <= 8192,
      let source = NSImage(contentsOfFile: arguments[1]), source.size.width > 0 else {
    FileHandle.standardError.write(Data("Usage: render-svg input.svg output.png pixel-width\n".utf8))
    exit(2)
}
let height = max(1, Int((Double(width) * source.size.height / source.size.width).rounded()))
guard height <= 8192,
      let bitmap = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: width, pixelsHigh: height,
                                   bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true,
                                   isPlanar: false, colorSpaceName: .deviceRGB,
                                   bytesPerRow: width * 4, bitsPerPixel: 32),
      let context = NSGraphicsContext(bitmapImageRep: bitmap) else { exit(1) }
NSGraphicsContext.saveGraphicsState()
NSGraphicsContext.current = context
context.imageInterpolation = .high
source.draw(in: NSRect(x: 0, y: 0, width: width, height: height),
            from: .zero, operation: .copy, fraction: 1)
context.flushGraphics()
NSGraphicsContext.restoreGraphicsState()
guard let data = bitmap.representation(using: .png, properties: [:]) else { exit(1) }
try data.write(to: URL(fileURLWithPath: arguments[2]), options: .atomic)
