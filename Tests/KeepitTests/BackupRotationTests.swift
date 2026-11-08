import XCTest
@testable import Keepit

/// SEC12 — rotation deletes a file only when it is provably the archive its record describes
/// (`DESIGN-3.0.7.md`, SEC12). Every row of the failure table, against a plain folder with a
/// sentinel outside it, without a vault: `rotate` is a pure function of the registry and the folder.
final class BackupRotationTests: XCTestCase {
    var tmp: TempStorage!
    var root: URL!          // holds the backup folder and the sentinel
    var folder: URL!
    var sentinel: URL!
    let series = "0a0a0a0a-0a0a-4a0a-8a0a-0a0a0a0a0a0a"
    let other  = "0b0b0b0b-0b0b-4b0b-8b0b-0b0b0b0b0b0b"
    var destination: PlainFolderDestination!
    var t0 = Date(timeIntervalSince1970: 1_800_000_000)

    override func setUpWithError() throws {
        tmp = TempStorage()
        root = FileManager.default.temporaryDirectory.appendingPathComponent("keepit-rotation-\(UUID().uuidString)", isDirectory: true)
        folder = root.appendingPathComponent("backups", isDirectory: true)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        sentinel = root.appendingPathComponent("x")
        try Data("do not touch".utf8).write(to: sentinel)
        destination = PlainFolderDestination(folder)
    }

    override func tearDown() {
        for name in (try? FileManager.default.contentsOfDirectory(atPath: folder.path)) ?? [] {
            chmod(folder.appendingPathComponent(name).path, 0o644)
        }
        try? FileManager.default.removeItem(at: root)
        tmp.restore()
    }

    // MARK: helpers

    private func id(_ n: Int) -> String { String(format: "%08x-0000-4000-8000-000000000000", n) }

    /// A real archive of this series: file written, record describing it exactly.
    @discardableResult
    private func archive(_ n: Int, minutes: Int, bytes: Data? = nil, sourceID: String? = nil, write: Bool = true) throws -> BackupState.Record {
        let created = t0.addingTimeInterval(Double(minutes) * 60)
        let data = bytes ?? Data("archive \(n) \(String(repeating: "-", count: n))".utf8)
        let name = BackupEngine.fileName(created: created, sourceID: sourceID ?? series, backupID: id(n))
        if write { try data.write(to: folder.appendingPathComponent(name)) }
        return BackupState.Record(backupID: id(n), name: name, size: data.count, date: created, sha256: BackupEngine.sha256(data))
    }

    private func files() -> Set<String> { Set((try? FileManager.default.contentsOfDirectory(atPath: folder.path)) ?? []) }
    private func rotate(_ records: [BackupState.Record], keep: Int, sourceID: String? = nil) -> [BackupState.Record] {
        BackupEngine.rotate(records, keep: keep, sourceID: sourceID ?? series, in: destination)
    }
    private func sentinelIntact() -> Bool { (try? Data(contentsOf: sentinel)) == Data("do not touch".utf8) }

    // MARK: names

    func testOrdinaryRotationDeletesExactlyTheOldestAfterVerifyingThem() throws {
        let a = try archive(1, minutes: 0), b = try archive(2, minutes: 1), c = try archive(3, minutes: 2), d = try archive(4, minutes: 3)
        let out = rotate([a, b, c, d], keep: 2)
        XCTAssertEqual(Set(out.map(\.backupID)), [c.backupID, d.backupID])
        XCTAssertEqual(files(), [c.name, d.name])
    }

    func testNothingIsReadOrDeletedWithKeepOrFewerArchives() throws {
        let a = try archive(1, minutes: 0), b = try archive(2, minutes: 1)
        try FileManager.default.removeItem(at: folder.appendingPathComponent(a.name))   // gone, but with keep = 2 nothing is even checked
        let out = rotate([a, b], keep: 2)
        XCTAssertEqual(out.count, 2)
        XCTAssertEqual(files(), [b.name])
    }

    func testANameThatEscapesTheFolderIsForgottenAndNothingOutsideIsTouched() throws {
        let good = try archive(1, minutes: 0), newer = try archive(2, minutes: 1)
        var dotdot = good; dotdot.backupID = id(7); dotdot.name = "../x"; dotdot.size = 12
        var sub = good; sub.backupID = id(8); sub.name = "sub/\(good.name)"
        var abs = good; abs.backupID = id(9); abs.name = sentinel.path
        let out = rotate([dotdot, sub, abs, good, newer], keep: 1)
        XCTAssertTrue(sentinelIntact())
        XCTAssertEqual(Set(out.map(\.backupID)), [newer.backupID])
        XCTAssertEqual(files(), [newer.name], "the real old archive is rotated out; the crafted ones only forgotten")
    }

    func testAnotherSeriesFileWithARecordPointingAtItIsLeftAlone() throws {
        let foreign = try archive(1, minutes: 0, sourceID: other)   // its name carries the other Mac's id
        let a = try archive(2, minutes: 1), b = try archive(3, minutes: 2)
        let out = rotate([foreign, a, b], keep: 1)
        XCTAssertEqual(Set(out.map(\.backupID)), [b.backupID])
        XCTAssertTrue(files().contains(foreign.name), "not ours, whatever the registry says")
        XCTAssertFalse(files().contains(a.name))
    }

    // MARK: objects

    func testASymlinkUnderOurNameIsNotFollowedAndNotDeleted() throws {
        let a = try archive(1, minutes: 0, write: false)
        try FileManager.default.createSymbolicLink(at: folder.appendingPathComponent(a.name), withDestinationURL: sentinel)
        let b = try archive(2, minutes: 1), c = try archive(3, minutes: 2)
        let out = rotate([a, b, c], keep: 1)
        XCTAssertTrue(sentinelIntact())
        XCTAssertTrue(files().contains(a.name), "the link stays")
        XCTAssertFalse(out.map(\.backupID).contains(a.backupID), "the record is forgotten")
        XCTAssertFalse(files().contains(b.name), "the real old one is rotated")
    }

    func testADirectoryOrAFifoUnderOurNameIsNotDeleted() throws {
        let dir = try archive(1, minutes: 0, write: false)
        try FileManager.default.createDirectory(at: folder.appendingPathComponent(dir.name), withIntermediateDirectories: false)
        try Data("inside".utf8).write(to: folder.appendingPathComponent(dir.name).appendingPathComponent("inside"))
        let fifo = try archive(2, minutes: 1, write: false)
        XCTAssertEqual(mkfifo(folder.appendingPathComponent(fifo.name).path, 0o600), 0)
        let b = try archive(3, minutes: 2), c = try archive(4, minutes: 3)
        let out = rotate([dir, fifo, b, c], keep: 1)     // must not hang on the FIFO
        XCTAssertTrue(files().isSuperset(of: [dir.name, fifo.name]))
        XCTAssertTrue(FileManager.default.fileExists(atPath: folder.appendingPathComponent(dir.name).appendingPathComponent("inside").path))
        XCTAssertEqual(Set(out.map(\.backupID)), [c.backupID])
    }

    func testReplacedContentIsForgottenAndTheFileStays() throws {
        let sameSize = try archive(1, minutes: 0, write: false)
        try Data("archive 1 X".utf8).write(to: folder.appendingPathComponent(sameSize.name))   // same length, other bytes
        XCTAssertEqual(try Data(contentsOf: folder.appendingPathComponent(sameSize.name)).count, sameSize.size)
        let otherSize = try archive(2, minutes: 1, write: false)
        try Data("longer than the record says".utf8).write(to: folder.appendingPathComponent(otherSize.name))
        let b = try archive(3, minutes: 2), c = try archive(4, minutes: 3)
        let out = rotate([sameSize, otherSize, b, c], keep: 1)
        XCTAssertTrue(files().isSuperset(of: [sameSize.name, otherSize.name]))
        XCTAssertEqual(Set(out.map(\.backupID)), [c.backupID])
        XCTAssertFalse(files().contains(b.name))
    }

    // MARK: retention counts verified archives only (auditor's two C scenarios)

    func testAForgedNewerRecordWithoutAFileDoesNotDisplaceARealArchive() throws {
        let a = try archive(1, minutes: 0), b = try archive(2, minutes: 1), d = try archive(4, minutes: 3)
        let c = try archive(3, minutes: 2, write: false)          // newer than B, no file
        let out = rotate([a, b, c, d], keep: 2)
        XCTAssertEqual(files(), [b.name, d.name], "B and D kept; A rotated; C was never counted")
        XCTAssertEqual(Set(out.map(\.backupID)), [b.backupID, d.backupID])
    }

    func testADamagedNewerArchiveOfTheRightSizeDoesNotDisplaceARealArchive() throws {
        let a = try archive(1, minutes: 0), b = try archive(2, minutes: 1), d = try archive(4, minutes: 3)
        let c = try archive(3, minutes: 2)
        var bytes = try Data(contentsOf: folder.appendingPathComponent(c.name))
        bytes[0] ^= 0x01                                           // one bit, same size
        try bytes.write(to: folder.appendingPathComponent(c.name))
        let out = rotate([a, b, c, d], keep: 2)
        XCTAssertEqual(files(), [b.name, c.name, d.name], "C stays on disk (not ours to delete) but does not count")
        XCTAssertEqual(Set(out.map(\.backupID)), [b.backupID, d.backupID], "C's record is forgotten")
    }

    func testATransientErrorKeepsTheRecordAndDoesNotCount() throws {
        let a = try archive(1, minutes: 0), b = try archive(2, minutes: 1), c = try archive(3, minutes: 2)
        let cPath = folder.appendingPathComponent(c.name).path
        XCTAssertEqual(chmod(cPath, 0), 0)
        defer { chmod(cPath, 0o644) }
        guard getuid() != 0 else { throw XCTSkip("root reads a 0000 file") }
        let out = rotate([a, b, c], keep: 1)
        XCTAssertEqual(Set(out.map(\.backupID)), [b.backupID, c.backupID], "C stays for retry; B is the one verified archive kept")
        XCTAssertEqual(files(), [b.name, c.name], "A, verified and beyond keep, is rotated")
    }

    // MARK: duplicates and conflicts

    func testIdenticalDuplicateRecordsCountAsOneArchive() throws {
        let a = try archive(1, minutes: 0)
        let out = rotate([a, a], keep: 1)
        XCTAssertEqual(files(), [a.name], "with keep = 1 the only archive survives")
        XCTAssertEqual(out.count, 1)
    }

    func testRecordsThatDisagreeAboutOneArchiveDeleteNothingUnderTheirNames() throws {
        let a = try archive(1, minutes: 0)
        var twin = try archive(1, minutes: 5)                    // same id, another date → another name, also on disk
        twin.backupID = a.backupID
        let b = try archive(2, minutes: 10), c = try archive(3, minutes: 11)
        let out = rotate([a, twin, b, c], keep: 1)
        XCTAssertTrue(files().isSuperset(of: [a.name, twin.name]), "neither side of the conflict is deleted")
        XCTAssertTrue(out.contains(a) && out.contains(twin), "both verified, both kept for a human to sort out")
        XCTAssertFalse(files().contains(b.name), "the unambiguous old archive is still rotated")
        XCTAssertTrue(files().contains(c.name))
    }

    // MARK: the registry itself

    func testAMalformedSeriesIDDisablesRotation() throws {
        let a = try archive(1, minutes: 0), b = try archive(2, minutes: 1)
        let out = rotate([a, b], keep: 1, sourceID: "src-a")
        XCTAssertEqual(out, [a, b])
        XCTAssertEqual(files(), [a.name, b.name])
    }

    func testTheEngineDropsForeignAndUndecodableRecordsAtLoadAndKeepsTheRest() throws {
        let good = try archive(1, minutes: 0)
        let json = """
        {"dirty": false, "failures": 0, "records": [
          {"backupID": "\(good.backupID)", "name": "\(good.name)", "size": \(good.size), "date": "\(ISO8601DateFormatter().string(from: good.date))", "sha256": "\(good.sha256)"},
          {"backupID": "\(id(2))", "name": "../x", "size": 12, "date": "2026-01-01T00:00:00Z", "sha256": "\(good.sha256)"},
          {"backupID": "\(id(3))", "name": "Keepit-20260101T000000Z-\(other)-\(id(3)).keepit", "size": 1, "date": "2026-01-01T00:00:00Z", "sha256": "\(good.sha256)"},
          {"backupID": "\(id(4))", "name": "no-size-no-hash.keepit", "date": "2026-01-01T00:00:00Z"}
        ]}
        """
        let stateURL = Storage.directory.appendingPathComponent("backup.json")
        try FileManager.default.createDirectory(at: Storage.directory, withIntermediateDirectories: true)
        try Data(json.utf8).write(to: stateURL)
        let engine = BackupEngine(stateURL: stateURL, sourceID: series)
        XCTAssertEqual(engine.state.records, [good], "one bad record no longer resets the registry; the bad ones are dropped")
        XCTAssertTrue(sentinelIntact())
    }

    func testA306RegistryLoadsUnchanged() throws {
        let a = try archive(1, minutes: 0), b = try archive(2, minutes: 1)
        var state = BackupState(); state.records = [a, b]; state.lastSuccess = b.date; state.lastName = b.name
        let stateURL = Storage.directory.appendingPathComponent("backup.json")
        try FileManager.default.createDirectory(at: Storage.directory, withIntermediateDirectories: true)
        try JSONEncoder.iso.encode(state).write(to: stateURL)
        let engine = BackupEngine(stateURL: stateURL, sourceID: series)
        XCTAssertEqual(engine.state.records.map(\.backupID), [a.backupID, b.backupID])
        XCTAssertEqual(engine.state.lastName, b.name)
    }

    func testVerifyOutcomes() throws {
        let a = try archive(1, minutes: 0)
        let fd = open(folder.path, O_RDONLY | O_DIRECTORY)
        XCTAssertGreaterThanOrEqual(fd, 0)
        defer { close(fd) }
        XCTAssertEqual(BackupEngine.verify(a, in: fd), .verified)
        var wrongHash = a; wrongHash.sha256 = String(repeating: "0", count: 64)
        XCTAssertEqual(BackupEngine.verify(wrongHash, in: fd), .mismatch)
        var wrongSize = a; wrongSize.size += 1
        XCTAssertEqual(BackupEngine.verify(wrongSize, in: fd), .mismatch)
        var missing = a; missing.name = "nothing-here.keepit"
        XCTAssertEqual(BackupEngine.verify(missing, in: fd), .gone)
        var tooBig = a; tooBig.size = Limits.dataFileMaxBytes + 1
        XCTAssertEqual(BackupEngine.verify(tooBig, in: fd), .mismatch)
    }
}
