import XCTest
@testable import PinCore

final class GeminiAdapterTests: XCTestCase {

    private let sessionId = "11111111-1111-1111-1111-111111111111"
    private let timestamp = "2026-04-25T14:06:31.114Z"

    func testParsesUserAndGeminiMessages() {
        let root: [String: Any] = [
            "sessionId": sessionId,
            "summary": "test session",
            "messages": [
                [
                    "id": "m1",
                    "type": "info",
                    "content": "info",
                    "timestamp": timestamp
                ],
                [
                    "id": "m2",
                    "type": "user",
                    "content": "hi",
                    "timestamp": timestamp
                ],
                [
                    "id": "m3",
                    "type": "gemini",
                    "content": "hello there",
                    "timestamp": timestamp
                ]
            ]
        ]
        let msgs = GeminiAdapter.parseRoot(root)
        XCTAssertEqual(msgs.count, 2)
        XCTAssertEqual(msgs.map(\.role), [.user, .assistant])
        XCTAssertEqual(msgs.map(\.text), ["hi", "hello there"])
        XCTAssertEqual(msgs.first?.sourceTool, .gemini)
    }

    func testUserContentAsList() {
        let root: [String: Any] = [
            "sessionId": sessionId,
            "messages": [
                [
                    "id": "m1",
                    "type": "user",
                    "timestamp": timestamp,
                    "content": [
                        ["type": "text", "text": "part1"],
                        ["type": "text", "text": "part2"]
                    ]
                ]
            ]
        ]
        let msgs = GeminiAdapter.parseRoot(root)
        XCTAssertEqual(msgs.count, 1)
        XCTAssertEqual(msgs[0].text, "part1\n\npart2")
    }

    func testFiltersAngleTaggedUserMessage() {
        let root: [String: Any] = [
            "sessionId": sessionId,
            "messages": [
                [
                    "id": "m1",
                    "type": "user",
                    "timestamp": timestamp,
                    "content": "<system>x</system>"
                ]
            ]
        ]
        XCTAssertEqual(GeminiAdapter.parseRoot(root).count, 0)
    }

    func testExtractTitlePrefersSummary() {
        let root: [String: Any] = [
            "sessionId": sessionId,
            "summary": "weekly review",
            "messages": [
                ["id": "m1", "type": "user", "timestamp": timestamp, "content": "actually a long question..."]
            ]
        ]
        XCTAssertEqual(GeminiAdapter.extractTitle(from: root), "weekly review")
    }

    func testIntermediateGeminiWhenToolCallsPresent() {
        let root: [String: Any] = [
            "sessionId": sessionId,
            "messages": [
                [
                    "id": "m1",
                    "type": "gemini",
                    "timestamp": timestamp,
                    "content": "let me check",
                    "toolCalls": [
                        ["id": "tc1", "name": "read_file", "args": [:] as [String: Any]]
                    ]
                ],
                [
                    "id": "m2",
                    "type": "gemini",
                    "timestamp": timestamp,
                    "content": "final answer",
                    "toolCalls": [] as [Any]
                ]
            ]
        ]
        let msgs = GeminiAdapter.parseRoot(root)
        XCTAssertEqual(msgs.count, 2)
        XCTAssertEqual(msgs[0].kind, .assistantIntermediate)
        XCTAssertEqual(msgs[1].kind, .assistantFinal)
    }

    func testExtractTitleFallsBackToFirstUser() {
        let root: [String: Any] = [
            "sessionId": sessionId,
            "messages": [
                ["id": "m1", "type": "user", "timestamp": timestamp, "content": "what is UCS?"]
            ]
        ]
        XCTAssertEqual(GeminiAdapter.extractTitle(from: root), "what is UCS?")
    }
}
