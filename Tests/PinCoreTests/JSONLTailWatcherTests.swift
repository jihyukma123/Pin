import XCTest
@testable import PinCore

final class JSONLTailWatcherTests: XCTestCase {

    func testEmitsExistingLinesWhenIncluded() async throws {
        let url = makeTempFile()
        try Data("a\nb\n".utf8).write(to: url)

        let watcher = JSONLTailWatcher(url: url, queue: .main)
        let collected = Collector()
        watcher.onLine = { line in collected.append(line) }
        try watcher.start(includeExisting: true)

        try await Task.sleep(nanoseconds: 50_000_000)
        watcher.stop()

        XCTAssertEqual(collected.lines, ["a", "b"])
    }

    func testEmitsNewlyAppendedLines() async throws {
        let url = makeTempFile()
        try Data("seed\n".utf8).write(to: url)

        let watcher = JSONLTailWatcher(url: url, queue: .main)
        let collected = Collector()
        watcher.onLine = { line in collected.append(line) }
        try watcher.start(includeExisting: false)

        try await Task.sleep(nanoseconds: 50_000_000)

        let handle = try FileHandle(forWritingTo: url)
        try handle.seekToEnd()
        try handle.write(contentsOf: Data("hello\nworld\n".utf8))
        try handle.close()

        // FSEvents/DispatchSource latency
        try await Task.sleep(nanoseconds: 600_000_000)

        watcher.stop()

        XCTAssertEqual(collected.lines, ["hello", "world"])
    }

    private func makeTempFile() -> URL {
        let dir = FileManager.default.temporaryDirectory
        return dir.appendingPathComponent("pin-tail-\(UUID().uuidString).jsonl")
    }

    private final class Collector: @unchecked Sendable {
        private let lock = NSLock()
        private var _lines: [String] = []
        var lines: [String] {
            lock.lock(); defer { lock.unlock() }
            return _lines
        }
        func append(_ s: String) {
            lock.lock(); defer { lock.unlock() }
            _lines.append(s)
        }
    }
}
