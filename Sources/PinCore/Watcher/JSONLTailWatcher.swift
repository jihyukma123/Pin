import Foundation

/// JSONL 파일을 append-only로 가정하고 새 줄을 incremental하게 읽어 콜백한다.
public final class JSONLTailWatcher: @unchecked Sendable {

    private let url: URL
    private let queue: DispatchQueue
    private var fileHandle: FileHandle?
    private var dispatchSource: DispatchSourceFileSystemObject?
    private var leftover: Data = Data()

    public var onLine: ((String) -> Void)?

    public init(url: URL, queue: DispatchQueue = .main) {
        self.url = url
        self.queue = queue
    }

    /// 호출 시점부터 끝까지 읽고, 이후엔 append되는 줄만 콜백한다.
    /// includeExisting=true면 처음에 파일 전체를 읽어 콜백한다.
    public func start(includeExisting: Bool) throws {
        let handle = try FileHandle(forReadingFrom: url)
        self.fileHandle = handle

        if includeExisting {
            try drain(handle: handle)
        } else {
            try handle.seekToEnd()
        }

        let source = DispatchSource.makeFileSystemObjectSource(
            fileDescriptor: handle.fileDescriptor,
            eventMask: [.write, .extend, .delete, .rename],
            queue: queue
        )
        source.setEventHandler { [weak self] in
            self?.handleEvent()
        }
        source.setCancelHandler { [weak self] in
            try? self?.fileHandle?.close()
            self?.fileHandle = nil
        }
        source.activate()
        self.dispatchSource = source
    }

    public func stop() {
        dispatchSource?.cancel()
        dispatchSource = nil
    }

    private func handleEvent() {
        guard let handle = fileHandle else { return }
        do {
            try drain(handle: handle)
        } catch {
            // best-effort; 다음 이벤트에서 재시도
        }
    }

    private func drain(handle: FileHandle) throws {
        guard let chunk = try handle.readToEnd(), !chunk.isEmpty else { return }
        var buffer = leftover + chunk
        while let nlRange = buffer.range(of: Data([0x0A])) {
            let lineData = buffer.subdata(in: 0..<nlRange.lowerBound)
            buffer.removeSubrange(0..<nlRange.upperBound)
            if let line = String(data: lineData, encoding: .utf8), !line.isEmpty {
                onLine?(line)
            }
        }
        leftover = buffer
    }
}
