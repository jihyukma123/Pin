import Foundation

public enum GeminiLocator {

    public static var tmpRoot: URL {
        let home = FileManager.default.homeDirectoryForCurrentUser
        return home.appendingPathComponent(".gemini/tmp", isDirectory: true)
    }

    public static func listSessions() -> [SessionRef] {
        let fm = FileManager.default
        guard let projectDirs = try? fm.contentsOfDirectory(
            at: tmpRoot,
            includingPropertiesForKeys: nil,
            options: [.skipsHiddenFiles]
        ) else {
            return []
        }

        var sessions: [SessionRef] = []
        for projDir in projectDirs {
            let chatsDir = projDir.appendingPathComponent("chats")
            guard let chats = try? fm.contentsOfDirectory(
                at: chatsDir,
                includingPropertiesForKeys: [.contentModificationDateKey],
                options: [.skipsHiddenFiles]
            ) else { continue }

            for file in chats {
                let ext = file.pathExtension
                if ext == "json" {
                    if let ref = makeRefFromJSON(file) { sessions.append(ref) }
                } else if ext == "jsonl" {
                    if let ref = makeRefFromJSONL(file) { sessions.append(ref) }
                }
            }
        }

        return sessions.sorted { $0.lastModified > $1.lastModified }
    }

    private static func makeRefFromJSON(_ url: URL) -> SessionRef? {
        guard let data = try? Data(contentsOf: url),
              let root = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return nil
        }
        guard let sessionId = root["sessionId"] as? String else { return nil }
        let title = GeminiAdapter.extractTitle(from: root) ?? "session-\(String(sessionId.prefix(8)))"
        return SessionRef(
            id: sessionId,
            title: title,
            sourceTool: .gemini,
            fileURL: url,
            lastModified: mtime(url)
        )
    }

    private static func makeRefFromJSONL(_ url: URL) -> SessionRef? {
        guard let data = try? Data(contentsOf: url),
              let text = String(data: data, encoding: .utf8) else {
            return nil
        }
        guard let meta = GeminiAdapter.extractMetaFromJSONL(text: text) else { return nil }
        let title: String = {
            if let t = meta.firstUserText, !t.isEmpty {
                return String(t.prefix(60))
            }
            return "session-\(String(meta.sessionId.prefix(8)))"
        }()
        return SessionRef(
            id: meta.sessionId,
            title: title,
            sourceTool: .gemini,
            fileURL: url,
            lastModified: mtime(url)
        )
    }
}
