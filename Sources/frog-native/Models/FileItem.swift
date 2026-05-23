import Foundation
import ImageIO
import UniformTypeIdentifiers
import AppKit

struct FileItem: Identifiable, Hashable {
    enum GitStatus {
        case clean
        case modified
        case added
        case deleted
        case untracked
    }
    
    var gitStatus: GitStatus = .clean
    
    var id: URL { url }
    let url: URL
    let name: String
    let isDirectory: Bool
    let size: Int64
    let modificationDate: Date
    let creationDate: Date
    var children: [FileItem]?
    
    let dimensions: String?
    let fileTypeDescription: String?
    
    var isImage: Bool {
        let imageExtensions = ["png", "jpg", "jpeg", "gif", "svg"]
        return imageExtensions.contains(url.pathExtension.lowercased())
    }
    
    var recencyScore: Double {
        let now = Date()
        let interval = now.timeIntervalSince(modificationDate)
        
        // 1.0 for modified in the last hour
        // 0.5 for modified 1 day ago
        // 0.1 for modified 1 week ago
        // 0.0 for older than a month
        let day: TimeInterval = 86400
        let week: TimeInterval = day * 7
        let month: TimeInterval = day * 30
        
        if interval < 3600 { return 1.0 }
        if interval < day { return 0.7 + (0.3 * (1.0 - interval / day)) }
        if interval < week { return 0.3 + (0.4 * (1.0 - interval / week)) }
        if interval < month { return 0.1 * (1.0 - interval / month) }
        return 0.0
    }
    
    init(url: URL, children: [FileItem]? = nil) {
        self.url = url
        self.name = url.lastPathComponent
        self.children = children
        
        let resources = try? url.resourceValues(forKeys: [.isDirectoryKey, .fileSizeKey, .contentModificationDateKey, .creationDateKey, .contentTypeKey])
        self.isDirectory = resources?.isDirectory ?? false
        self.size = Int64(resources?.fileSize ?? 0)
        self.modificationDate = resources?.contentModificationDate ?? Date.distantPast
        self.creationDate = resources?.creationDate ?? Date.distantPast
        
        // Extract dimensions for image files
        if !isDirectory {
            let imageExtensions = ["png", "jpg", "jpeg", "gif", "svg"]
            if imageExtensions.contains(url.pathExtension.lowercased()) {
                if let imageSource = CGImageSourceCreateWithURL(url as CFURL, nil),
                   let imageProperties = CGImageSourceCopyPropertiesAtIndex(imageSource, 0, nil) as? [CFString: Any] {
                    let width = imageProperties[kCGImagePropertyPixelWidth] as? Int ?? 0
                    let height = imageProperties[kCGImagePropertyPixelHeight] as? Int ?? 0
                    if width > 0 && height > 0 {
                        self.dimensions = "\(width)×\(height) px"
                    } else {
                        self.dimensions = nil
                    }
                } else {
                    self.dimensions = nil
                }
            } else {
                self.dimensions = nil
            }
        } else {
            self.dimensions = nil
        }
        
        // File type description
        if let contentType = resources?.contentType {
            self.fileTypeDescription = contentType.localizedDescription
        } else {
            self.fileTypeDescription = isDirectory ? "Folder" : "File"
        }
    }
}
