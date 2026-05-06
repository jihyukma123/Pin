import XCTest
@testable import PinCore

final class ClaudeCodeAdapterTests: XCTestCase {

    private func line(_ dict: [String: Any]) -> String {
        let data = try! JSONSerialization.data(withJSONObject: dict, options: [])
        return String(data: data, encoding: .utf8)!
    }

    private let baseUUID = "11111111-1111-1111-1111-111111111111"
    private let sessionId = "00000000-0000-0000-0000-000000000001"
    private let timestamp = "2026-05-05T01:00:00.000Z"

    func testIgnoresNonUserAssistantTypes() {
        let l = line([
            "type": "system",
            "uuid": baseUUID,
            "sessionId": sessionId,
            "timestamp": timestamp
        ])
        XCTAssertNil(ClaudeCodeAdapter.parse(line: l))
    }

    func testFiltersUserSystemTaggedString() {
        let l = line([
            "type": "user",
            "uuid": baseUUID,
            "sessionId": sessionId,
            "timestamp": timestamp,
            "message": ["role": "user", "content": "<command-name>/clear</command-name>"]
        ])
        XCTAssertNil(ClaudeCodeAdapter.parse(line: l))
    }

    func testParsesPlainUserText() throws {
        let l = line([
            "type": "user",
            "uuid": baseUUID,
            "sessionId": sessionId,
            "timestamp": timestamp,
            "message": ["role": "user", "content": "hello"]
        ])
        let msg = try XCTUnwrap(ClaudeCodeAdapter.parse(line: l))
        XCTAssertEqual(msg.role, .user)
        XCTAssertEqual(msg.text, "hello")
        XCTAssertEqual(msg.id, baseUUID)
        XCTAssertEqual(msg.sourceTool, .claudeCode)
    }

    func testParsesAssistantTextBlocksAndIgnoresThinking() throws {
        let l = line([
            "type": "assistant",
            "uuid": baseUUID,
            "sessionId": sessionId,
            "timestamp": timestamp,
            "message": [
                "role": "assistant",
                "stop_reason": "end_turn",
                "content": [
                    ["type": "thinking", "thinking": "x"],
                    ["type": "text", "text": "# Title\n\nbody"]
                ]
            ]
        ])
        let msg = try XCTUnwrap(ClaudeCodeAdapter.parse(line: l))
        XCTAssertEqual(msg.role, .assistant)
        XCTAssertEqual(msg.text, "# Title\n\nbody")
        XCTAssertEqual(msg.kind, .assistantFinal)
    }

    func testIntermediateAssistantWhenStopReasonToolUse() throws {
        let l = line([
            "type": "assistant",
            "uuid": baseUUID,
            "sessionId": sessionId,
            "timestamp": timestamp,
            "message": [
                "role": "assistant",
                "stop_reason": "tool_use",
                "content": [
                    ["type": "text", "text": "Let me check the file"],
                    ["type": "tool_use", "id": "x", "name": "Read", "input": [:] as [String: Any]]
                ]
            ]
        ])
        let msg = try XCTUnwrap(ClaudeCodeAdapter.parse(line: l))
        XCTAssertEqual(msg.kind, .assistantIntermediate)
        XCTAssertEqual(msg.text, "Let me check the file")
    }

    func testFinalWhenStopReasonAbsent() throws {
        let l = line([
            "type": "assistant",
            "uuid": baseUUID,
            "sessionId": sessionId,
            "timestamp": timestamp,
            "message": [
                "role": "assistant",
                "content": [
                    ["type": "text", "text": "answer"]
                ]
            ]
        ])
        let msg = try XCTUnwrap(ClaudeCodeAdapter.parse(line: l))
        XCTAssertEqual(msg.kind, .assistantFinal)
    }

    func testUserKind() throws {
        let l = line([
            "type": "user",
            "uuid": baseUUID,
            "sessionId": sessionId,
            "timestamp": timestamp,
            "message": ["role": "user", "content": "hi"]
        ])
        let msg = try XCTUnwrap(ClaudeCodeAdapter.parse(line: l))
        XCTAssertEqual(msg.kind, .userInput)
    }

    func testToolUseOnlyAssistantIsNil() {
        let l = line([
            "type": "assistant",
            "uuid": baseUUID,
            "sessionId": sessionId,
            "timestamp": timestamp,
            "message": [
                "role": "assistant",
                "content": [
                    ["type": "tool_use", "id": "x", "name": "Bash", "input": [:] as [String: Any]]
                ]
            ]
        ])
        XCTAssertNil(ClaudeCodeAdapter.parse(line: l))
    }

    func testToolResultUserIsNil() {
        let l = line([
            "type": "user",
            "uuid": baseUUID,
            "sessionId": sessionId,
            "timestamp": timestamp,
            "message": [
                "role": "user",
                "content": [
                    ["type": "tool_result", "tool_use_id": "x", "content": "out", "is_error": false]
                ]
            ]
        ])
        XCTAssertNil(ClaudeCodeAdapter.parse(line: l))
    }

    func testJoinsMultipleTextBlocks() throws {
        let l = line([
            "type": "assistant",
            "uuid": baseUUID,
            "sessionId": sessionId,
            "timestamp": timestamp,
            "message": [
                "role": "assistant",
                "content": [
                    ["type": "text", "text": "part 1"],
                    ["type": "text", "text": "part 2"]
                ]
            ]
        ])
        let msg = try XCTUnwrap(ClaudeCodeAdapter.parse(line: l))
        XCTAssertEqual(msg.text, "part 1\n\npart 2")
    }

    func testParseFixtureFile() throws {
        let url = try XCTUnwrap(
            Bundle.module.url(forResource: "sample", withExtension: "jsonl", subdirectory: "Fixtures")
            ?? Bundle.module.url(forResource: "Fixtures/sample", withExtension: "jsonl")
        )
        let data = try Data(contentsOf: url)
        let text = String(data: data, encoding: .utf8) ?? ""
        let messages = text.split(separator: "\n").compactMap { ClaudeCodeAdapter.parse(line: String($0)) }
        XCTAssertEqual(messages.count, 3)
        XCTAssertEqual(messages.map(\.role), [.user, .assistant, .assistant])
    }
}
