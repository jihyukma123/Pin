import Foundation

public enum CodexLocator {

    public static var sessionsRoot: URL {
        let home = FileManager.default.homeDirectoryForCurrentUser
        return home.appendingPathComponent(".codex/sessions", isDirectory: true)
    }

    public static var sessionIndex: URL {
        let home = FileManager.default.homeDirectoryForCurrentUser
        return home.appendingPathComponent(".codex/session_index.jsonl")
    }

    public static func listSessions() -> [SessionRef] {
        let files = enumerateFiles(in: sessionsRoot, extensions: ["jsonl"])
        let titleIndex = loadIndex()

        return files.compactMap { url -> SessionRef? in
            guard let id = sessionId(from: url) else { return nil }
            guard hasMeaningfulUserMessage(in: url) else { return nil }
            let title = titleIndex[id]
                ?? extractTitleFromBody(url: url)
                ?? "session-\(String(id.prefix(8)))"
            return SessionRef(
                id: id,
                title: title,
                sourceTool: .codex,
                fileURL: url,
                lastModified: mtime(url),
                projectLabel: extractProjectLabel(url: url)
            )
        }
        .sorted { $0.lastModified > $1.lastModified }
    }

    /// 파일명: rollout-2026-01-28T23-39-03-019c050b-2b33-73b3-856c-9c5dd48ae67d.jsonl
    /// 마지막 5 hyphen-separated parts (UUID with hyphens)을 결합.
    private static func sessionId(from url: URL) -> String? {
        let stem = url.deletingPathExtension().lastPathComponent
        let parts = stem.split(separator: "-")
        guard parts.count >= 5 else { return nil }
        let uuidParts = parts.suffix(5)
        return uuidParts.joined(separator: "-")
    }

    private static func loadIndex() -> [String: String] {
        guard let handle = try? FileHandle(forReadingFrom: sessionIndex) else { return [:] }
        defer { try? handle.close() }
        let data = (try? handle.readToEnd()) ?? Data()
        guard let text = String(data: data, encoding: .utf8) else { return [:] }
        var map: [String: String] = [:]
        for line in text.split(separator: "\n") {
            guard let lineData = line.data(using: .utf8),
                  let obj = try? JSONSerialization.jsonObject(with: lineData) as? [String: Any],
                  let id = obj["id"] as? String,
                  let name = obj["thread_name"] as? String else { continue }
            map[id] = name
        }
        return map
    }

    /// 의미 있는 사용자 메시지가 1개라도 있는지. 슬래시 명령/환경 컨텍스트는 제외.
    private static func hasMeaningfulUserMessage(in url: URL) -> Bool {
        let lines = readFirstLines(of: url, maxBytes: 512_000)
        for line in lines {
            guard let data = line.data(using: .utf8),
                  let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { continue }
            guard obj["type"] as? String == "response_item",
                  let payload = obj["payload"] as? [String: Any],
                  payload["type"] as? String == "message",
                  payload["role"] as? String == "user",
                  let blocks = payload["content"] as? [[String: Any]] else { continue }
            for block in blocks {
                if block["type"] as? String == "input_text",
                   let text = block["text"] as? String,
                   isMeaningfulUserText(text) {
                    return true
                }
            }
        }
        return false
    }

    /// 첫 줄의 session_meta.payload.cwd에서 마지막 path component를 추출.
    private static func extractProjectLabel(url: URL) -> String? {
        // 첫 줄(session_meta)에 base_instructions 통째가 들어있어 수십 KB가 될 수 있다.
        let lines = readFirstLines(of: url, maxBytes: 512_000)
        for line in lines {
            guard let data = line.data(using: .utf8),
                  let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { continue }
            guard obj["type"] as? String == "session_meta",
                  let payload = obj["payload"] as? [String: Any],
                  let cwd = payload["cwd"] as? String, !cwd.isEmpty else { continue }
            let last = (cwd as NSString).lastPathComponent
            return last.isEmpty ? nil : last
        }
        return nil
    }

    private static func extractTitleFromBody(url: URL) -> String? {
        let lines = readFirstLines(of: url, maxBytes: 200_000)
        for line in lines {
            guard let data = line.data(using: .utf8),
                  let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { continue }
            guard obj["type"] as? String == "response_item",
                  let payload = obj["payload"] as? [String: Any],
                  payload["type"] as? String == "message",
                  payload["role"] as? String == "user",
                  let blocks = payload["content"] as? [[String: Any]] else { continue }
            for block in blocks {
                if block["type"] as? String == "input_text", let text = block["text"] as? String,
                   !text.hasPrefix("<") {
                    return String(text.prefix(60))
                }
            }
        }
        return nil
    }
}
