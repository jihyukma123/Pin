import XCTest
@testable import PinCore

@MainActor
final class MessageStoreTests: XCTestCase {

    override func setUp() {
        super.setUp()
        UserDefaults.standard.removeObject(forKey: "pin.messageSortOrder")
    }

    private func msg(_ id: String, kind: MessageKind = .assistantFinal, ts: Double = 0) -> ParsedMessage {
        ParsedMessage(
            id: id,
            sessionId: "s",
            role: kind == .userInput ? .user : .assistant,
            kind: kind,
            text: "t",
            timestamp: Date(timeIntervalSince1970: ts),
            sourceTool: .claudeCode
        )
    }

    func testNewestFirstReversesArrivalOrder() {
        let store = MessageStore()
        store.sortOrder = .newestFirst
        store._injectMessagesForTesting([msg("a"), msg("b"), msg("c")])
        XCTAssertEqual(store.visibleMessages.map(\.id), ["c", "b", "a"])
    }

    func testOldestFirstKeepsArrivalOrder() {
        let store = MessageStore()
        store.sortOrder = .oldestFirst
        store._injectMessagesForTesting([msg("a"), msg("b"), msg("c")])
        XCTAssertEqual(store.visibleMessages.map(\.id), ["a", "b", "c"])
    }

    func testIntermediateHiddenByDefault() {
        let store = MessageStore()
        store.sortOrder = .oldestFirst
        store._injectMessagesForTesting([
            msg("a", kind: .userInput),
            msg("b", kind: .assistantIntermediate),
            msg("c", kind: .assistantFinal)
        ])
        XCTAssertEqual(store.visibleMessages.map(\.id), ["a", "c"])
    }

    func testPinnedIntermediateAlwaysVisible() {
        let store = MessageStore()
        store.sortOrder = .oldestFirst
        store._injectMessagesForTesting([
            msg("a", kind: .userInput),
            msg("b", kind: .assistantIntermediate),
            msg("c", kind: .assistantFinal)
        ])
        store.togglePin("b")
        XCTAssertEqual(store.visibleMessages.map(\.id), ["a", "b", "c"])
    }

    func testPinnedSortFollowsOrder() {
        let store = MessageStore()
        store.sortOrder = .newestFirst
        store._injectMessagesForTesting([msg("a"), msg("b"), msg("c")])
        store.togglePin("a")
        store.togglePin("c")
        XCTAssertEqual(store.pinned.map(\.id), ["c", "a"])
    }

    func testSortOrderPersistsToUserDefaults() {
        let store = MessageStore()
        store.sortOrder = .oldestFirst
        XCTAssertEqual(UserDefaults.standard.string(forKey: "pin.messageSortOrder"), "oldestFirst")

        let store2 = MessageStore()
        XCTAssertEqual(store2.sortOrder, .oldestFirst)
    }
}
