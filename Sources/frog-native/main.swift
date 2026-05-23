import AppKit

let app = NSApplication.shared

if let exportRequest = IconExportRequest(arguments: CommandLine.arguments) {
    do {
        let outputURL = try AuraIconExporter.exportIconset(to: exportRequest.outputURL)
        FileHandle.standardOutput.write(Data("\(outputURL.path)\n".utf8))
        exit(EXIT_SUCCESS)
    } catch {
        FileHandle.standardError.write(Data("Icon export failed: \(error.localizedDescription)\n".utf8))
        exit(EXIT_FAILURE)
    }
}

app.setActivationPolicy(.regular)

let delegate = AppDelegate()
app.delegate = delegate
app.run()

private struct IconExportRequest {
    let outputURL: URL?

    init?(arguments: [String]) {
        guard arguments.count >= 2, arguments[1] == "--export-app-iconset" else {
            return nil
        }

        if arguments.count >= 3 {
            outputURL = URL(fileURLWithPath: arguments[2], isDirectory: true)
        } else {
            outputURL = nil
        }
    }
}
