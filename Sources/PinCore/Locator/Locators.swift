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

func readFirstLines(of url: URL, maxBytes: Int) -> [String] {
    guard let handle = try? FileHandle(forReadingFrom: url) else { return [] }
    defer { try? handle.close() }
    let data = (try? handle.read(upToCount: maxBytes)) ?? Data()
    guard let text = String(data: data, encoding: .utf8) else { return [] }
    return text.split(separator: "\n").map(String.init)
}
