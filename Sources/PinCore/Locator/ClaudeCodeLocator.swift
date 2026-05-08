import Foundation

public enum ClaudeCodeLocator {

    public static var projectsRoot: URL {
        let home = FileManager.default.homeDirectoryForCurrentUser
        return home.appendingPathComponent(".claude/projects", isDirectory: true)
    }

    public static func listSessions() -> [SessionRef] {
        let files = enumerateFiles(in: projectsRoot, extensions: ["jsonl"])
        return files
            .filter { hasMeaningfulUserMessage(in: $0) }
            .map { url -> SessionRef in
                let id = url.deletingPathExtension().lastPathComponent
                let title = extractTitle(from: url) ?? defaultTitle(for: url)
                return SessionRef(
                    id: id,
                    title: title,
                    sourceTool: .claudeCode,
                    fileURL: url,
                    lastModified: mtime(url),
                    projectLabel: projectLabel(for: url)
                )
            }
            .sorted { $0.lastModified > $1.lastModified }
    }

    public static func latestSessionFile() -> URL? {
        listSessions().first?.fileURL
    }

    private static func extractTitle(from url: URL) -> String? {
        let lines = readFirstLines(of: url, maxBytes: 256_000)
        var firstUserText: String?
        for line in lines {
            guard let data = line.data(using: .utf8),
                  let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { continue }
            if obj["type"] as? String == "ai-title", let title = obj["aiTitle"] as? String, !title.isEmpty {
                return title
            }
            if firstUserText == nil, obj["type"] as? String == "user",
               let msg = obj["message"] as? [String: Any] {
                if let text = msg["content"] as? String,
                   !text.hasPrefix("<") {
                    firstUserText = text
                } else if let blocks = msg["content"] as? [[String: Any]] {
                    for block in blocks {
                        if block["type"] as? String == "text", let t = block["text"] as? String {
                            firstUserText = t
                            break
                        }
                    }
                }
            }
        }
        if let t = firstUserText {
            return String(t.prefix(60))
        }
        return nil
    }

    private static func defaultTitle(for url: URL) -> String {
        // 인코딩된 cwd가 부모 디렉토리 이름. e.g. "-Users-jihyukma-Documents-c-pin"
        let cwd = url.deletingLastPathComponent().lastPathComponent
        let projectHint = cwd.replacingOccurrences(of: "-", with: "/").trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        let id = String(url.deletingPathExtension().lastPathComponent.prefix(8))
        return "\(projectHint) — \(id)"
    }

    /// 세션 파일을 훑어 의미 있는 사용자 메시지가 1개라도 있는지 확인. 없으면 빈 세션으로 간주해 listing에서 제외.
    private static func hasMeaningfulUserMessage(in url: URL) -> Bool {
        let lines = readFirstLines(of: url, maxBytes: 512_000)
        for line in lines {
            guard let data = line.data(using: .utf8),
                  let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { continue }
            guard obj["type"] as? String == "user",
                  let msg = obj["message"] as? [String: Any] else { continue }
            if let text = msg["content"] as? String, isMeaningfulUserText(text) {
                return true
            }
            if let blocks = msg["content"] as? [[String: Any]] {
                for block in blocks {
                    if block["type"] as? String == "text",
                       let t = block["text"] as? String,
                       isMeaningfulUserText(t) {
                        return true
                    }
                }
            }
        }
        return false
    }

    /// 부모 디렉토리명("-Users-jeff-Documents-c-pin")에서 마지막 path component만 추출.
    /// `/`는 `-`로 인코딩돼 있으므로 마지막 `-` 뒤를 취한다. 디렉토리명에 `-`가 있으면 손실되지만
    /// 라벨 용도로는 충분.
    private static func projectLabel(for url: URL) -> String? {
        let parent = url.deletingLastPathComponent().lastPathComponent
        let parts = parent.split(separator: "-", omittingEmptySubsequences: true)
        guard let last = parts.last else { return nil }
        return String(last)
    }
}
