import Foundation
import CryptoKit

public enum GeminiLocator {

    public static var tmpRoot: URL {
        let home = FileManager.default.homeDirectoryForCurrentUser
        return home.appendingPathComponent(".gemini/tmp", isDirectory: true)
    }

    public static var projectsManifest: URL {
        let home = FileManager.default.homeDirectoryForCurrentUser
        return home.appendingPathComponent(".gemini/projects.json")
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

        let hashToLabel = loadHashToLabelMap()

        var sessions: [SessionRef] = []
        for projDir in projectDirs {
            let label = projectLabel(for: projDir, hashToLabel: hashToLabel)
            let chatsDir = projDir.appendingPathComponent("chats")
            guard let chats = try? fm.contentsOfDirectory(
                at: chatsDir,
                includingPropertiesForKeys: [.contentModificationDateKey],
                options: [.skipsHiddenFiles]
            ) else { continue }

            for file in chats {
                let ext = file.pathExtension
                if ext == "json" {
                    if let ref = makeRefFromJSON(file, projectLabel: label) { sessions.append(ref) }
                } else if ext == "jsonl" {
                    if let ref = makeRefFromJSONL(file, projectLabel: label) { sessions.append(ref) }
                }
            }
        }

        return sessions.sorted { $0.lastModified > $1.lastModified }
    }

    /// `~/.gemini/tmp/<dir>`의 `<dir>`에서 사람이 읽을 수 있는 라벨을 만든다.
    /// - 평문 디렉토리(신형)면 그대로 사용.
    /// - 64-hex SHA-256(구형)이면 `projects.json`을 통해 cwd → label로 역산.
    private static func projectLabel(for dir: URL, hashToLabel: [String: String]) -> String? {
        let name = dir.lastPathComponent
        if isHexHash(name) {
            return hashToLabel[name]
        }
        return name
    }

    private static func isHexHash(_ s: String) -> Bool {
        guard s.count == 64 else { return false }
        return s.allSatisfy { $0.isHexDigit }
    }

    /// `~/.gemini/projects.json`을 읽어 `SHA256(cwd) → friendlyName` 매핑을 만든다.
    private static func loadHashToLabelMap() -> [String: String] {
        guard let data = try? Data(contentsOf: projectsManifest),
              let root = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let projects = root["projects"] as? [String: String] else {
            return [:]
        }
        var map: [String: String] = [:]
        for (cwd, name) in projects {
            map[sha256Hex(cwd)] = name
        }
        return map
    }

    private static func sha256Hex(_ s: String) -> String {
        let digest = SHA256.hash(data: Data(s.utf8))
        return digest.map { String(format: "%02x", $0) }.joined()
    }

    private static func makeRefFromJSON(_ url: URL, projectLabel: String?) -> SessionRef? {
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
            lastModified: mtime(url),
            projectLabel: projectLabel
        )
    }

    private static func makeRefFromJSONL(_ url: URL, projectLabel: String?) -> SessionRef? {
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
            lastModified: mtime(url),
            projectLabel: projectLabel
        )
    }
}
