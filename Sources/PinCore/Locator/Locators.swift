import Foundation

/// 도구별로 세션 목록을 만들어내는 공통 진입점.
public enum SessionDiscovery {

    public static func listAll() -> [SourceTool: [SessionRef]] {
        return [
            .claudeCode: ClaudeCodeLocator.listSessions(),
            .codex: CodexLocator.listSessions(),
            .gemini: GeminiLocator.listSessions(),
        ]
    }

    public static func list(for tool: SourceTool) -> [SessionRef] {
        switch tool {
        case .claudeCode: return ClaudeCodeLocator.listSessions()
        case .codex: return CodexLocator.listSessions()
        case .gemini: return GeminiLocator.listSessions()
        }
    }
}

// MARK: - Helpers

func mtime(_ url: URL) -> Date {
    (try? url.resourceValues(forKeys: [.contentModificationDateKey]))?.contentModificationDate ?? .distantPast
}

func enumerateFiles(in directory: URL, extensions: Set<String>) -> [URL] {
    let fm = FileManager.default
    var results: [URL] = []
    guard let enumerator = fm.enumerator(
        at: directory,
        includingPropertiesForKeys: [.contentModificationDateKey, .isRegularFileKey],
        options: [.skipsHiddenFiles]
    ) else { return [] }
    for case let url as URL in enumerator {
        guard extensions.contains(url.pathExtension) else { continue }
        if let isFile = (try? url.resourceValues(forKeys: [.isRegularFileKey]))?.isRegularFile, isFile {
            results.append(url)
        }
    }
    return results
}

/// 빈 세션(아무 질의도 안 한 세션) 판별 기준:
/// - `<...>` 로 시작하는 환경 컨텍스트성 메시지 제외
/// - `/clear`, `/model` 등 슬래시 명령 제외
/// - 그 외 비어있지 않은 사용자 텍스트가 1개 이상이면 "의미 있는 대화" 로 본다.
func isMeaningfulUserText(_ text: String) -> Bool {
    let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !trimmed.isEmpty else { return false }
    if trimmed.hasPrefix("<") { return false }
    if trimmed.hasPrefix("/") { return false }
    return true
}

func readFirstLines(of url: URL, maxBytes: Int) -> [String] {
    guard let handle = try? FileHandle(forReadingFrom: url) else { return [] }
    defer { try? handle.close() }
    let data = (try? handle.read(upToCount: maxBytes)) ?? Data()
    guard let text = String(data: data, encoding: .utf8) else { return [] }
    return text.split(separator: "\n").map(String.init)
}
