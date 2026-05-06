import Foundation

public enum ClaudeCodeLocator {

    public static var projectsRoot: URL {
        let home = FileManager.default.homeDirectoryForCurrentUser
        return home.appendingPathComponent(".claude/projects", isDirectory: true)
    }

    public static func listSessions() -> [SessionRef] {
        let files = enumerateFiles(in: projectsRoot, extensions: ["jsonl"])
        return files
            .map { url -> SessionRef in
                let id = url.deletingPathExtension().lastPathComponent
                let title = extractTitle(from: url) ?? defaultTitle(for: url)
                return SessionRef(
                    id: id,
                    title: title,
                    sourceTool: .claudeCode,
                    fileURL: url,
                    lastModified: mtime(url)
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
}
