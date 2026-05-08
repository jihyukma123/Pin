import Foundation
import Combine

@MainActor
public final class MessageStore: ObservableObject {

    @Published public private(set) var sessionsByTool: [SourceTool: [SessionRef]] = [:]
    @Published public var selectedTool: SourceTool? = nil
    @Published public private(set) var selectedSession: SessionRef? = nil

    @Published public private(set) var messages: [ParsedMessage] = []
    @Published public private(set) var pinnedIds: Set<String> = []
    @Published public private(set) var expandedIds: Set<String> = []
    @Published public var showIntermediate: Bool = false
    @Published public var sortOrder: MessageSortOrder = .newestFirst {
        didSet {
            UserDefaults.standard.set(sortOrder.rawValue, forKey: Self.sortOrderKey)
        }
    }

    private static let sortOrderKey = "pin.messageSortOrder"
    private static let pinnedBySessionKey = "pin.pinnedBySession"

    private var watcher: SessionWatcher?
    private var directoryWatcher: DirectoryWatcher?
    private var pinnedBySession: [String: [String]] = [:]

    public init() {
        if let raw = UserDefaults.standard.string(forKey: Self.sortOrderKey),
           let order = MessageSortOrder(rawValue: raw) {
            self.sortOrder = order
        }
        if let dict = UserDefaults.standard.dictionary(forKey: Self.pinnedBySessionKey)
            as? [String: [String]] {
            self.pinnedBySession = dict
        }
    }

    private func sessionKey(_ ref: SessionRef) -> String {
        "\(ref.sourceTool.rawValue):\(ref.id)"
    }

    private func persistPinned() {
        guard let ref = selectedSession else { return }
        let key = sessionKey(ref)
        if pinnedIds.isEmpty {
            pinnedBySession.removeValue(forKey: key)
        } else {
            pinnedBySession[key] = Array(pinnedIds)
        }
        UserDefaults.standard.set(pinnedBySession, forKey: Self.pinnedBySessionKey)
    }

    public func refreshSessions() {
        sessionsByTool = SessionDiscovery.listAll()
        if selectedTool == nil {
            selectedTool = firstNonEmptyTool()
        }
        startDirectoryWatcherIfNeeded()
    }

    /// 도구별 세션 루트가 변경되면 자동으로 세션 목록을 다시 스캔한다.
    /// 첫 refreshSessions 시점에 한 번만 띄운다.
    private func startDirectoryWatcherIfNeeded() {
        guard directoryWatcher == nil else { return }
        let paths = [
            ClaudeCodeLocator.projectsRoot.path,
            CodexLocator.sessionsRoot.path,
            GeminiLocator.tmpRoot.path,
        ]
        let w = DirectoryWatcher(paths: paths)
        w.onChange = { [weak self] in
            // FSEvents 큐에서 호출 → 무거운 디렉터리 스캔은 백그라운드에서.
            // 결과가 실제로 변했을 때만 main에서 publish (SwiftUI 노이즈 방지).
            DispatchQueue.global(qos: .utility).async { [weak self] in
                let next = SessionDiscovery.listAll()
                DispatchQueue.main.async { [weak self] in
                    MainActor.assumeIsolated {
                        guard let self else { return }
                        if next != self.sessionsByTool {
                            self.sessionsByTool = next
                        }
                    }
                }
            }
        }
        w.start()
        directoryWatcher = w
    }

    public func selectTool(_ tool: SourceTool) {
        selectedTool = tool
        // 세션 선택 유지: 도구가 같으면 그대로, 아니면 해제
        if selectedSession?.sourceTool != tool {
            selectedSession = nil
            messages = []
            pinnedIds = []
            expandedIds = []
            watcher?.stop()
            watcher = nil
        }
    }

    public func openSession(_ ref: SessionRef) {
        watcher?.stop()
        watcher = nil
        messages = []
        pinnedIds = Set(pinnedBySession[sessionKey(ref)] ?? [])
        expandedIds = []
        selectedSession = ref
        selectedTool = ref.sourceTool

        let w = SessionWatcherFactory.make(for: ref)
        w.onMessages = { [weak self] msgs in
            Task { @MainActor [weak self] in
                self?.messages = msgs
            }
        }
        w.start()
        watcher = w
    }

    public func stop() {
        watcher?.stop()
        watcher = nil
        directoryWatcher?.stop()
        directoryWatcher = nil
    }

    public var pinned: [ParsedMessage] {
        applySort(messages.filter { pinnedIds.contains($0.id) })
    }

    /// UI에 표시할 메시지. showIntermediate가 false면 intermediate를 숨긴다.
    /// 핀된 intermediate는 의도적으로 핀했으므로 항상 보인다.
    /// sortOrder에 따라 정렬.
    public var visibleMessages: [ParsedMessage] {
        let filtered: [ParsedMessage]
        if showIntermediate {
            filtered = messages
        } else {
            filtered = messages.filter { msg in
                msg.kind != .assistantIntermediate || pinnedIds.contains(msg.id)
            }
        }
        return applySort(filtered)
    }

    private func applySort(_ list: [ParsedMessage]) -> [ParsedMessage] {
        // messages는 도착 순(=오래된 것이 먼저)으로 누적됨.
        sortOrder == .newestFirst ? list.reversed() : list
    }

    public var intermediateCount: Int {
        messages.lazy.filter { $0.kind == .assistantIntermediate }.count
    }

    public func togglePin(_ id: String) {
        if pinnedIds.contains(id) {
            pinnedIds.remove(id)
        } else {
            pinnedIds.insert(id)
        }
        persistPinned()
    }

    public func isPinned(_ id: String) -> Bool {
        pinnedIds.contains(id)
    }

    /// Test seam — production code never calls directly.
    /// 실제 메시지 주입은 watcher 콜백 경로로만 일어난다.
    func _injectMessagesForTesting(_ msgs: [ParsedMessage]) {
        self.messages = msgs
    }

    public func toggleExpanded(_ id: String) {
        if expandedIds.contains(id) {
            expandedIds.remove(id)
        } else {
            expandedIds.insert(id)
        }
    }

    public func isExpanded(_ id: String) -> Bool {
        expandedIds.contains(id)
    }

    private func firstNonEmptyTool() -> SourceTool? {
        for tool in [SourceTool.claudeCode, .codex, .gemini] {
            if !(sessionsByTool[tool]?.isEmpty ?? true) {
                return tool
            }
        }
        return SourceTool.claudeCode
    }
}
