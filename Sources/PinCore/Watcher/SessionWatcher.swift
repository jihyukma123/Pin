import Foundation

/// 세션 단위 watcher. start하면 onMessages 콜백으로 (전체) 메시지 리스트를 emit한다.
/// 도구별 파일 형태(append-only JSONL vs 단일 JSON)에 무관하게 같은 인터페이스.
public protocol SessionWatcher: AnyObject {
    var onMessages: (([ParsedMessage]) -> Void)? { get set }
    func start()
    func stop()
}

public enum SessionWatcherFactory {
    @MainActor
    public static func make(for ref: SessionRef) -> SessionWatcher {
        switch ref.sourceTool {
        case .claudeCode:
            return JSONLLineSessionWatcher(ref: ref) { line in
                ClaudeCodeAdapter.parse(line: line)
            }
        case .codex:
            return JSONLLineSessionWatcher(ref: ref) { line in
                CodexAdapter.parse(line: line, sessionId: ref.id, fallbackId: { UUID().uuidString })
            }
        case .gemini:
            return GeminiFileSessionWatcher(ref: ref)
        }
    }
}

/// JSONL append-only 파일을 tail하면서 한 줄당 한 ParsedMessage를 만드는 어댑터를 적용.
public final class JSONLLineSessionWatcher: SessionWatcher, @unchecked Sendable {
    public var onMessages: (([ParsedMessage]) -> Void)?

    private let ref: SessionRef
    private let parseLine: @Sendable (String) -> ParsedMessage?
    private var tail: JSONLTailWatcher?
    private var accumulated: [ParsedMessage] = []
    private var seenIds: Set<String> = []
    private let lock = NSLock()

    public init(ref: SessionRef, parseLine: @escaping @Sendable (String) -> ParsedMessage?) {
        self.ref = ref
        self.parseLine = parseLine
    }

    public func start() {
        let watcher = JSONLTailWatcher(url: ref.fileURL, queue: .main)
        watcher.onLine = { [weak self] line in
            guard let self else { return }
            guard let msg = self.parseLine(line) else { return }
            self.append(msg)
        }
        do {
            try watcher.start(includeExisting: true)
            self.tail = watcher
        } catch {
            self.tail = nil
        }
    }

    public func stop() {
        tail?.stop()
        tail = nil
    }

    private func append(_ msg: ParsedMessage) {
        lock.lock()
        if seenIds.contains(msg.id) {
            lock.unlock()
            return
        }
        seenIds.insert(msg.id)
        accumulated.append(msg)
        let snapshot = accumulated
        lock.unlock()
        onMessages?(snapshot)
    }
}

/// Gemini는 단일 JSON 파일이 매번 통째로 재기록됨. 변경 시 전체 다시 파싱.
public final class GeminiFileSessionWatcher: SessionWatcher, @unchecked Sendable {
    public var onMessages: (([ParsedMessage]) -> Void)?

    private let ref: SessionRef
    private var fileHandle: FileHandle?
    private var dispatchSource: DispatchSourceFileSystemObject?

    public init(ref: SessionRef) {
        self.ref = ref
    }

    public func start() {
        emit()

        let fd = open(ref.fileURL.path, O_EVTONLY)
        guard fd >= 0 else { return }
        let source = DispatchSource.makeFileSystemObjectSource(
            fileDescriptor: fd,
            eventMask: [.write, .extend, .delete, .rename, .attrib],
            queue: .main
        )
        source.setEventHandler { [weak self] in
            self?.emit()
        }
        source.setCancelHandler {
            close(fd)
        }
        source.activate()
        dispatchSource = source
    }

    public func stop() {
        dispatchSource?.cancel()
        dispatchSource = nil
    }

    private func emit() {
        let messages = GeminiAdapter.parseFile(at: ref.fileURL)
        onMessages?(messages)
    }
}
