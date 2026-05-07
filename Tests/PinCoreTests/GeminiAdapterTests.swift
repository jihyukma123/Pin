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

    func testParsesNewJSONLFormat() {
        let lines = [
            "{\"sessionId\":\"\(sessionId)\",\"projectHash\":\"abc\",\"startTime\":\"\(timestamp)\",\"kind\":\"main\"}",
            "{\"id\":\"i1\",\"type\":\"info\",\"content\":\"update available\",\"timestamp\":\"\(timestamp)\"}",
            "{\"id\":\"u1\",\"type\":\"user\",\"timestamp\":\"\(timestamp)\",\"content\":[{\"text\":\"hi\"}]}",
            "{\"$set\":{\"lastUpdated\":\"\(timestamp)\"}}",
            "{\"id\":\"g1\",\"type\":\"gemini\",\"timestamp\":\"\(timestamp)\",\"content\":\"\",\"thoughts\":[{\"subject\":\"x\",\"description\":\"y\"}]}",
            "{\"id\":\"g2\",\"type\":\"gemini\",\"timestamp\":\"\(timestamp)\",\"content\":\"final answer\"}",
            "{\"id\":\"g3\",\"type\":\"gemini\",\"timestamp\":\"\(timestamp)\",\"content\":\"checking files\",\"toolCalls\":[{\"id\":\"tc\",\"name\":\"read\"}]}"
        ]
        let msgs = GeminiAdapter.parseJSONL(text: lines.joined(separator: "\n"))
        XCTAssertEqual(msgs.count, 3)
        XCTAssertEqual(msgs.map(\.role), [.user, .assistant, .assistant])
        XCTAssertEqual(msgs.map(\.text), ["hi", "final answer", "checking files"])
        XCTAssertEqual(msgs.map(\.kind), [.userInput, .assistantFinal, .assistantIntermediate])
        XCTAssertEqual(msgs[0].sessionId, sessionId)
    }

    func testExtractMetaFromJSONL() throws {
        let lines = [
            "{\"sessionId\":\"\(sessionId)\",\"projectHash\":\"abc\",\"startTime\":\"\(timestamp)\"}",
            "{\"id\":\"u1\",\"type\":\"user\",\"timestamp\":\"\(timestamp)\",\"content\":[{\"text\":\"first question\"}]}"
        ]
        let meta = try XCTUnwrap(GeminiAdapter.extractMetaFromJSONL(text: lines.joined(separator: "\n")))
        XCTAssertEqual(meta.sessionId, sessionId)
        XCTAssertEqual(meta.firstUserText, "first question")
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
