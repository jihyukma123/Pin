import Foundation

public enum ClaudeCodeAdapter {

    public static let sourceTool: SourceTool = .claudeCode

    public static func parse(line: String) -> ParsedMessage? {
        guard let data = line.data(using: .utf8) else { return nil }
        guard let raw = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return nil
        }
        return parse(event: raw)
    }

    public static func parse(event: [String: Any]) -> ParsedMessage? {
        guard let type = event["type"] as? String else { return nil }
        guard type == "user" || type == "assistant" else { return nil }

        let role: Role = type == "user" ? .user : .assistant
        guard let id = event["uuid"] as? String,
              let sessionId = event["sessionId"] as? String,
              let timestampString = event["timestamp"] as? String,
              let timestamp = parseISO8601(timestampString) else {
            return nil
        }

        guard let message = event["message"] as? [String: Any] else { return nil }

        let text = extractText(content: message["content"], role: role)
        guard !text.isEmpty else { return nil }

        let kind: MessageKind = {
            if role == .user { return .userInput }
            // stop_reason="tool_use"이면 이 응답은 다음 턴에 도구 호출 → intermediate
            // 그 외(end_turn, max_tokens 등)는 사용자에게 보일 final
            if let stop = message["stop_reason"] as? String, stop == "tool_use" {
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

    private static func extractText(content: Any?, role: Role) -> String {
        if let str = content as? String {
            return filterUserString(str)
        }
        if let blocks = content as? [[String: Any]] {
            let texts = blocks.compactMap { block -> String? in
                guard let blockType = block["type"] as? String, blockType == "text" else { return nil }
                return block["text"] as? String
            }
            return texts.joined(separator: "\n\n").trimmingCharacters(in: .whitespacesAndNewlines)
        }
        return ""
    }

    private static func filterUserString(_ str: String) -> String {
        let trimmed = str.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return "" }
        if trimmed.hasPrefix("<") && trimmed.contains(">") {
            return ""
        }
        return trimmed
    }
}

func parseISO8601(_ s: String) -> Date? {
    let f = ISO8601DateFormatter()
    f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
    if let d = f.date(from: s) { return d }
    f.formatOptions = [.withInternetDateTime]
    return f.date(from: s)
}
