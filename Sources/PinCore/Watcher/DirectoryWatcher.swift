import Foundation
import CoreServices

/// 여러 디렉터리 서브트리를 동시에 감시한다. 변경(create/delete/rename/write)이 일어나면
/// debounce 후 onChange를 부른다. 어떤 파일이 바뀌었는지는 알리지 않으며,
/// 호출자가 listAll을 다시 돌려 diff 하도록 한다 — 디렉터리 스캔은 빠르고 단순하다.
public final class DirectoryWatcher: @unchecked Sendable {
    public var onChange: (@Sendable () -> Void)?

    private let paths: [String]
    private let debounceInterval: TimeInterval
    private let queue = DispatchQueue(label: "pin.directory-watcher")
    private var stream: FSEventStreamRef?
    private var debounceItem: DispatchWorkItem?

    public init(paths: [String], debounceInterval: TimeInterval = 0.5) {
        // 존재하는 경로만 등록. 없는 경로를 섞으면 이벤트가 누락될 수 있음.
        let fm = FileManager.default
        self.paths = paths.filter { path in
            var isDir: ObjCBool = false
            return fm.fileExists(atPath: path, isDirectory: &isDir) && isDir.boolValue
        }
        self.debounceInterval = debounceInterval
    }

    public func start() {
        guard stream == nil, !paths.isEmpty else { return }

        var context = FSEventStreamContext(
            version: 0,
            info: Unmanaged.passUnretained(self).toOpaque(),
            retain: nil,
            release: nil,
            copyDescription: nil
        )

        let callback: FSEventStreamCallback = { _, info, _, _, _, _ in
            guard let info else { return }
            let watcher = Unmanaged<DirectoryWatcher>.fromOpaque(info).takeUnretainedValue()
            watcher.scheduleFire()
        }

        let flags = FSEventStreamCreateFlags(
            kFSEventStreamCreateFlagFileEvents | kFSEventStreamCreateFlagNoDefer
        )

        guard let s = FSEventStreamCreate(
            kCFAllocatorDefault,
            callback,
            &context,
            paths as CFArray,
            FSEventStreamEventId(kFSEventStreamEventIdSinceNow),
            0.2,
            flags
        ) else { return }

        FSEventStreamSetDispatchQueue(s, queue)
        FSEventStreamStart(s)
        stream = s
    }

    public func stop() {
        debounceItem?.cancel()
        debounceItem = nil
        guard let s = stream else { return }
        FSEventStreamStop(s)
        FSEventStreamInvalidate(s)
        FSEventStreamRelease(s)
        stream = nil
    }

    private func scheduleFire() {
        debounceItem?.cancel()
        let item = DispatchWorkItem { [weak self] in
            self?.onChange?()
        }
        debounceItem = item
        queue.asyncAfter(deadline: .now() + debounceInterval, execute: item)
    }

    deinit { stop() }
}
