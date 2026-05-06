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

            for file in chats where file.pathExtension == "json" {
                guard let ref = makeRef(from: file) else { continue }
                sessions.append(ref)
            }
        }

        return sessions.sorted { $0.lastModified > $1.lastModified }
    }

    private static func makeRef(from url: URL) -> SessionRef? {
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
}
