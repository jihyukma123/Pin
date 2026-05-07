import Foundation

/// Codex CLI 트랜스크립트 한 줄 → ParsedMessage.
/// 라인 형태: {"timestamp", "type", "payload": {...}}
/// type=="response_item" + payload.type=="message" + payload.role in {user, assistant}일 때만 산출.
public enum CodexAdapter {

    public static let sourceTool: SourceTool = .codex

    public static func parse(line: String, sessionId: String, fallbackId: () -> String) -> ParsedMessage? {
        guard let data = line.data(using: .utf8) else { return nil }
        guard let raw = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return nil
        }
        return parse(event: raw, sessionId: sessionId, fallbackId: fallbackId)
    }

    public static func parse(event: [String: Any], sessionId: String, fallbackId: () -> String) -> ParsedMessage? {
        guard event["type"] as? String == "response_item" else { return nil }
        guard let payload = event["payload"] as? [String: Any] else { return nil }
        guard payload["type"] as? String == "message" else { return nil }
        guard let roleStr = payload["role"] as? String,
              let role: Role = roleFrom(roleStr) else { return nil }

        guard let timestampStr = event["timestamp"] as? String,
              let timestamp = parseISO8601(timestampStr) else {
            return nil
        }

        let text = extractText(content: payload["content"])
        guard !text.isEmpty else { return nil }

        let id = (payload["id"] as? String) ?? fallbackId()

        // Codex는 assistant 메시지에 phase 필드를 둔다.
        // - "final_answer" (또는 누락): 사용자에게 보내는 최종 답변
        // - "commentary": 도구 호출 사이의 중간 코멘트 (thinking)
        // user는 항상 userInput.
        let kind: MessageKind
        if role == .user {
            kind = .userInput
        } else {
            let phase = payload["phase"] as? String
            kind = (phase == "commentary") ? .assistantIntermediate : .assistantFinal
        }

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

    private static func roleFrom(_ s: String) -> Role? {
        switch s {
        case "user": return .user
        case "assistant": return .assistant
        default: return nil   // developer/system 등은 무시
        }
    }

    private static func extractText(content: Any?) -> String {
        guard let blocks = content as? [[String: Any]] else { return "" }
        let texts = blocks.compactMap { block -> String? in
            guard let bt = block["type"] as? String else { return nil }
            switch bt {
            case "input_text", "output_text":
                guard let raw = block["text"] as? String else { return nil }
                let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
                if trimmed.hasPrefix("<") && trimmed.contains(">") { return nil }
                return trimmed
            default:
                return nil
            }
        }
        return texts.joined(separator: "\n\n").trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
