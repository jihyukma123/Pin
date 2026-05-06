import Foundation

/// Gemini CLI 세션 파일 (단일 JSON) → [ParsedMessage].
/// 파일 구조: { sessionId, summary?, messages: [{id, timestamp, type, content, ...}] }
public enum GeminiAdapter {

    public static let sourceTool: SourceTool = .gemini

    public static func parseFile(at url: URL) -> [ParsedMessage] {
        guard let data = try? Data(contentsOf: url),
              let root = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
        else {
            return []
        }
        return parseRoot(root)
    }

    public static func parseRoot(_ root: [String: Any]) -> [ParsedMessage] {
        guard let sessionId = root["sessionId"] as? String,
              let messages = root["messages"] as? [[String: Any]] else {
            return []
        }
        return messages.compactMap { parseMessage($0, sessionId: sessionId) }
    }

    public static func extractTitle(from root: [String: Any]) -> String? {
        if let summary = root["summary"] as? String, !summary.isEmpty {
            return summary
        }
        if let messages = root["messages"] as? [[String: Any]] {
            for m in messages {
                if m["type"] as? String == "user", let text = userText(m["content"]), !text.isEmpty {
                    return String(text.prefix(60))
                }
            }
        }
        return nil
    }

    private static func parseMessage(_ m: [String: Any], sessionId: String) -> ParsedMessage? {
        guard let typeStr = m["type"] as? String else { return nil }
        let role: Role
        switch typeStr {
        case "user": role = .user
        case "gemini": role = .assistant
        default: return nil   // info 등 무시
        }

        guard let id = m["id"] as? String else { return nil }
        guard let timestampStr = m["timestamp"] as? String,
              let timestamp = parseISO8601(timestampStr) else {
            return nil
        }

        let text: String
        if role == .user {
            guard let extracted = userText(m["content"]), !extracted.isEmpty else { return nil }
            text = extracted
        } else {
            guard let raw = m["content"] as? String else { return nil }
            text = raw.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !text.isEmpty else { return nil }
        }

        let kind: MessageKind = {
            if role == .user { return .userInput }
            // toolCalls가 있는 gemini 메시지 = 도구 호출 직전의 코멘트 → intermediate
            if let calls = m["toolCalls"] as? [Any], !calls.isEmpty {
                return .assistantIntermediate
            }
            return .assistantFinal
        }()

        return ParsedMessage(
            id: id,
            sessionId: sessionId,
            role: role,
            kind: kind,
            text: text,
            timestamp: timestamp,
            sourceTool: sourceTool
        )
    }

    /// Gemini의 user content는 string 또는 list. list면 part-shaped 객체들에서 text를 추출.
    private static func userText(_ content: Any?) -> String? {
        if let s = content as? String {
            let t = s.trimmingCharacters(in: .whitespacesAndNewlines)
            if t.isEmpty { return nil }
            if t.hasPrefix("<") && t.contains(">") { return nil }
            return t
        }
        if let list = content as? [Any] {
            var pieces: [String] = []
            for item in list {
                if let s = item as? String {
                    pieces.append(s)
                } else if let dict = item as? [String: Any] {
                    if let s = dict["text"] as? String { pieces.append(s) }
                    if let s = dict["content"] as? String { pieces.append(s) }
                }
            }
            let joined = pieces.joined(separator: "\n\n").trimmingCharacters(in: .whitespacesAndNewlines)
            if joined.hasPrefix("<") && joined.contains(">") { return nil }
            return joined.isEmpty ? nil : joined
        }
        return nil
    }
}
