import XCTest
@testable import PinCore

final class CodexAdapterTests: XCTestCase {

    private func line(_ dict: [String: Any]) -> String {
        let data = try! JSONSerialization.data(withJSONObject: dict, options: [])
        return String(data: data, encoding: .utf8)!
    }

    private let timestamp = "2026-01-28T14:39:04.001Z"
    private let sessionId = "019c050b-2b33-73b3-856c-9c5dd48ae67d"

    func testIgnoresSessionMeta() {
        let l = line([
            "timestamp": timestamp,
            "type": "session_meta",
            "payload": ["id": sessionId]
        ])
        XCTAssertNil(CodexAdapter.parse(line: l, sessionId: sessionId, fallbackId: { "fb" }))
    }

    func testParsesUserInputText() throws {
        let l = line([
            "timestamp": timestamp,
            "type": "response_item",
            "payload": [
                "type": "message",
                "role": "user",
                "content": [
                    ["type": "input_text", "text": "hello"]
                ]
            ]
        ])
        let msg = try XCTUnwrap(CodexAdapter.parse(line: l, sessionId: sessionId, fallbackId: { "fb" }))
        XCTAssertEqual(msg.role, .user)
        XCTAssertEqual(msg.text, "hello")
        XCTAssertEqual(msg.sessionId, sessionId)
        XCTAssertEqual(msg.sourceTool, .codex)
    }

    func testParsesAssistantOutputText() throws {
        let l = line([
            "timestamp": timestamp,
            "type": "response_item",
            "payload": [
                "type": "message",
                "role": "assistant",
                "content": [
                    ["type": "output_text", "text": "world"]
                ]
            ]
        ])
        let msg = try XCTUnwrap(CodexAdapter.parse(line: l, sessionId: sessionId, fallbackId: { "fb" }))
        XCTAssertEqual(msg.role, .assistant)
        XCTAssertEqual(msg.text, "world")
    }

    func testFiltersAngleTaggedSystemInjections() {
        let l = line([
            "timestamp": timestamp,
            "type": "response_item",
            "payload": [
                "type": "message",
                "role": "user",
                "content": [
                    ["type": "input_text", "text": "<environment_context>cwd</environment_context>"]
                ]
            ]
        ])
        XCTAssertNil(CodexAdapter.parse(line: l, sessionId: sessionId, fallbackId: { "fb" }))
    }

    func testIgnoresDeveloperRole() {
        let l = line([
            "timestamp": timestamp,
            "type": "response_item",
            "payload": [
                "type": "message",
                "role": "developer",
                "content": [
                    ["type": "input_text", "text": "instructions"]
                ]
            ]
        ])
        XCTAssertNil(CodexAdapter.parse(line: l, sessionId: sessionId, fallbackId: { "fb" }))
    }

    func testCommentaryPhaseIsIntermediate() throws {
        let l = line([
            "timestamp": timestamp,
            "type": "response_item",
            "payload": [
                "type": "message",
                "role": "assistant",
                "phase": "commentary",
                "content": [
                    ["type": "output_text", "text": "let me check"]
                ]
            ]
        ])
        let msg = try XCTUnwrap(CodexAdapter.parse(line: l, sessionId: sessionId, fallbackId: { "fb" }))
        XCTAssertEqual(msg.kind, .assistantIntermediate)
    }

    func testFinalAnswerPhaseIsFinal() throws {
        let l = line([
            "timestamp": timestamp,
            "type": "response_item",
            "payload": [
                "type": "message",
                "role": "assistant",
                "phase": "final_answer",
                "content": [
                    ["type": "output_text", "text": "done"]
                ]
            ]
        ])
        let msg = try XCTUnwrap(CodexAdapter.parse(line: l, sessionId: sessionId, fallbackId: { "fb" }))
        XCTAssertEqual(msg.kind, .assistantFinal)
    }

    func testIgnoresFunctionCall() {
        let l = line([
            "timestamp": timestamp,
            "type": "response_item",
            "payload": [
                "type": "function_call",
                "name": "read"
            ]
        ])
        XCTAssertNil(CodexAdapter.parse(line: l, sessionId: sessionId, fallbackId: { "fb" }))
    }
}
