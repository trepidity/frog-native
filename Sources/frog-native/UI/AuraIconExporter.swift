import Foundation

@MainActor
enum AuraIconExporter {
    private struct IconDefinition {
        let filename: String
        let pixelSize: Int
    }

    private static let iconDefinitions: [IconDefinition] = [
        .init(filename: "icon_16x16.png", pixelSize: 16),
        .init(filename: "icon_16x16@2x.png", pixelSize: 32),
        .init(filename: "icon_32x32.png", pixelSize: 32),
        .init(filename: "icon_32x32@2x.png", pixelSize: 64),
        .init(filename: "icon_128x128.png", pixelSize: 128),
        .init(filename: "icon_128x128@2x.png", pixelSize: 256),
        .init(filename: "icon_256x256.png", pixelSize: 256),
        .init(filename: "icon_256x256@2x.png", pixelSize: 512),
        .init(filename: "icon_512x512.png", pixelSize: 512),
        .init(filename: "icon_512x512@2x.png", pixelSize: 1024)
    ]

    static func exportIconset(to outputURL: URL? = nil) throws -> URL {
        let fileManager = FileManager.default
        let iconsetURL = resolvedOutputURL(from: outputURL)

        try fileManager.createDirectory(at: iconsetURL, withIntermediateDirectories: true)

        for definition in iconDefinitions {
            guard let pngData = AuraIconRenderer.renderPNGData(pixelSize: definition.pixelSize) else {
                throw ExportError.renderFailed(pixelSize: definition.pixelSize)
            }

            let fileURL = iconsetURL.appendingPathComponent(definition.filename)
            try pngData.write(to: fileURL, options: .atomic)
        }

        return iconsetURL
    }

    private static func resolvedOutputURL(from outputURL: URL?) -> URL {
        let baseURL = outputURL ?? defaultOutputURL()
        if baseURL.pathExtension == "iconset" {
            return baseURL
        }
        return baseURL.appendingPathComponent("AppIcon.iconset", isDirectory: true)
    }

    private static func defaultOutputURL() -> URL {
        let fileManager = FileManager.default
        let workingDirectoryURL = URL(fileURLWithPath: fileManager.currentDirectoryPath, isDirectory: true)
        let packageURL = workingDirectoryURL.appendingPathComponent("Package.swift")

        if fileManager.fileExists(atPath: packageURL.path) {
            return workingDirectoryURL
                .appendingPathComponent("Assets", isDirectory: true)
                .appendingPathComponent("AppIcon.iconset", isDirectory: true)
        }

        return URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("Assets", isDirectory: true)
            .appendingPathComponent("AppIcon.iconset", isDirectory: true)
    }

    enum ExportError: LocalizedError {
        case renderFailed(pixelSize: Int)

        var errorDescription: String? {
            switch self {
            case let .renderFailed(pixelSize):
                return "Failed to render \(pixelSize)x\(pixelSize) icon image."
            }
        }
    }
}
