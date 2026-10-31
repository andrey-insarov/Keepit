import XCTest
@testable import Keepit

/// Points Storage at a fresh temporary folder for the duration of a test.
final class TempStorage {
    let dir: URL
    private let previous: URL
    init() {
        previous = Storage.directory
        dir = FileManager.default.temporaryDirectory.appendingPathComponent("keepit-tests-\(UUID().uuidString)", isDirectory: true)
        Storage.directory = dir
    }
    func restore() {
        Storage.clearKey()
        Storage.directory = previous
        try? FileManager.default.removeItem(at: dir)
    }
}

extension SecureBuffer {
    static func of(_ s: String) -> SecureBuffer {
        let b = SecureBuffer()
        Array(s.utf8).withUnsafeBytes { _ = b.append($0) }
        return b
    }
}
