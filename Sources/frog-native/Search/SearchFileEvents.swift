import Foundation
import CoreServices

@MainActor
final class SearchFileEvents {
    private var stream: FSEventStreamRef?
    private let handler: ([String], UInt64, Bool) -> Void

    init(roots: [String], since: UInt64, handler: @escaping ([String], UInt64, Bool) -> Void) throws {
        self.handler = handler
        var context = FSEventStreamContext(version: 0, info: Unmanaged.passUnretained(self).toOpaque(),
                                          retain: nil, release: nil, copyDescription: nil)
        let callback: FSEventStreamCallback = { _, context, count, rawPaths, flags, ids in
            guard let context else { return }
            let owner = Unmanaged<SearchFileEvents>.fromOpaque(context).takeUnretainedValue()
            let paths = unsafeBitCast(rawPaths, to: NSArray.self) as? [String] ?? []
            let droppedMask = UInt32(kFSEventStreamEventFlagUserDropped |
                                     kFSEventStreamEventFlagKernelDropped | kFSEventStreamEventFlagEventIdsWrapped |
                                     kFSEventStreamEventFlagRootChanged | kFSEventStreamEventFlagMount | kFSEventStreamEventFlagUnmount)
            let rebuild = (0..<count).contains { flags[$0] & droppedMask != 0 }
            let lastID = (0..<count).map { ids[$0] }.max() ?? 0
            let nameChanges = UInt32(kFSEventStreamEventFlagItemCreated | kFSEventStreamEventFlagItemRemoved |
                                     kFSEventStreamEventFlagItemRenamed | kFSEventStreamEventFlagMustScanSubDirs)
            let accessChanges = UInt32(kFSEventStreamEventFlagItemChangeOwner | kFSEventStreamEventFlagItemInodeMetaMod)
            let changed = paths.enumerated().filter { index, _ in
                let flag = flags[index]
                // Content writes don't alter filename search. Directory access changes
                // do matter: a previously denied subtree may now be readable.
                return flag & (nameChanges | droppedMask) != 0 ||
                    (flag & UInt32(kFSEventStreamEventFlagItemIsDir) != 0 && flag & accessChanges != 0)
            }.map(\.element)
            MainActor.assumeIsolated { owner.handler(changed, lastID, rebuild) }
        }
        stream = FSEventStreamCreate(nil, callback, &context, roots as CFArray, since, 0.3,
                                    UInt32(kFSEventStreamCreateFlagUseCFTypes | kFSEventStreamCreateFlagWatchRoot | kFSEventStreamCreateFlagFileEvents))
        guard let stream else { throw CocoaError(.fileReadUnknown) }
        FSEventStreamSetDispatchQueue(stream, DispatchQueue.main)
        guard FSEventStreamStart(stream) else {
            stop()
            throw CocoaError(.fileReadUnknown)
        }
    }

    func stop() {
        guard let stream else { return }
        FSEventStreamStop(stream)
        FSEventStreamInvalidate(stream)
        FSEventStreamRelease(stream)
        self.stream = nil
    }
}
