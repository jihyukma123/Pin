import Foundation

public enum Role: String, Sendable, Codable {
    case user
    case assistant
}

public enum SourceTool: String, Sendable, Codable, CaseIterable, Identifiable {
    case claudeCode
    case codex
    case gemini

    public var id: String { rawValue }

    public var displayName: String {
        switch self {
        case .claudeCode: return "Claude Code"
        case .codex: return "Codex"
        case .gemini: return "Gemini"
        }
    }
}

public enum MessageSortOrder: String, Sendable, Codable, CaseIterable, Identifiable {
    case newestFirst
    case oldestFirst

    public var id: String { rawValue }

    public var label: String {
        switch self {
        case .newestFirst: return "Newest first"
        case .oldestFirst: return "Oldest first"
        }
    }
}

/// 메시지의 흐름상 역할.
/// - `userInput`: 사용자 발화.
/// - `assistantFinal`: 에이전트가 사용자에게 돌려주는 최종 답변(턴 종료).
/// - `assistantIntermediate`: 도구 호출 사이에 끼어있는 에이전트의 중간 코멘트(thinking process). 기본은 숨김.
public enum MessageKind: String, Sendable, Codable, Hashable {
    case userInput
    case assistantFinal
    case assistantIntermediate
}

public struct ParsedMessage: Identifiable, Equatable, Sendable, Codable, Hashable {
    public let id: String
    public let sessionId: String
    public let role: Role
    public let kind: MessageKind
    public let text: String
    public let timestamp: Date
    public let sourceTool: SourceTool

    public init(id: String, sessionId: String, role: Role, kind: MessageKind, text: String, timestamp: Date, sourceTool: SourceTool) {
        self.id = id
        self.sessionId = sessionId
        self.role = role
        self.kind = kind
        self.text = text
        self.timestamp = timestamp
        self.sourceTool = sourceTool
    }
}

public struct SessionRef: Identifiable, Equatable, Sendable, Hashable {
    public let id: String
    public let title: String
    public let sourceTool: SourceTool
    public let fileURL: URL
    public let lastModified: Date

    public init(id: String, title: String, sourceTool: SourceTool, fileURL: URL, lastModified: Date) {
        self.id = id
        self.title = title
        self.sourceTool = sourceTool
        self.fileURL = fileURL
        self.lastModified = lastModified
    }
}
