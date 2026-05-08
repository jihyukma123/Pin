import XCTest
@testable import PinCore

final class DirectoryWatcherTests: XCTestCase {

    func testFiresOnFileCreation() async throws {
        let dir = makeTempDir()
        let watcher = DirectoryWatcher(paths: [dir.path], debounceInterval: 0.1)

        let exp = expectation(description: "onChange fires")
        exp.assertForOverFulfill = false
        watcher.onChange = { exp.fulfill() }
        watcher.start()
        defer { watcher.stop() }

        // FSEvents가 스트림을 등록할 시간을 잠깐 준 뒤 파일을 만든다.
        try await Task.sleep(nanoseconds: 200_000_000)
        try Data("hello".utf8).write(to: dir.appendingPathComponent("a.txt"))

        await fulfillment(of: [exp], timeout: 3.0)
    }

    func testFiresOnFileWriteInSubdirectory() async throws {
        let dir = makeTempDir()
        let sub = dir.appendingPathComponent("sub", isDirectory: true)
        try FileManager.default.createDirectory(at: sub, withIntermediateDirectories: true)

        let watcher = DirectoryWatcher(paths: [dir.path], debounceInterval: 0.1)
        let exp = expectation(description: "onChange fires for subdir write")
        exp.assertForOverFulfill = false
        watcher.onChange = { exp.fulfill() }
        watcher.start()
        defer { watcher.stop() }

        try await Task.sleep(nanoseconds: 200_000_000)
        try Data("x".utf8).write(to: sub.appendingPathComponent("b.txt"))

        await fulfillment(of: [exp], timeout: 3.0)
    }

    func testNoCrashOnMissingPaths() {
        let watcher = DirectoryWatcher(paths: ["/tmp/definitely-not-here-\(UUID().uuidString)"])
        watcher.start()
        watcher.stop()
    }

    private func makeTempDir() -> URL {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("pin-dirwatcher-\(UUID().uuidString)", isDirectory: true)
        try? FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }
}
