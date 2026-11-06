import AppKit
import XCTest
@testable import Keepit

/// Every external file comes in through `BoundedFileReader`; the Viewer's file import decides from
/// headers and limits before it decodes anything. Seeded from the auditor's external-input review
/// (5 Nov 2026): unbounded `Data(contentsOf:)`, image decode before the pixel check, a 50 MiB + 1
/// text accepted into the template tree.
final class BoundedReadTests: XCTestCase {
    private var dir: URL!

    override func setUpWithError() throws {
        dir = FileManager.default.temporaryDirectory.appendingPathComponent("keepit-bounded-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
    }
    override func tearDownWithError() throws { try? FileManager.default.removeItem(at: dir) }

    private func file(_ name: String, _ data: Data) throws -> URL {
        let u = dir.appendingPathComponent(name); try data.write(to: u); return u
    }

    // MARK: BoundedFileReader

    func testReadsAFileWithinTheLimitAndRefusesOneBytePast() throws {
        let ok = try file("ok.bin", Data(repeating: 7, count: 1000))
        XCTAssertEqual(try BoundedFileReader.read(ok, max: 1000).count, 1000)
        let big = try file("big.bin", Data(repeating: 7, count: 1001))
        XCTAssertThrowsError(try BoundedFileReader.read(big, max: 1000)) { e in
            XCTAssertEqual(e as? BoundedFileReader.Failure, .tooLarge(limit: 1000))
        }
        XCTAssertEqual(try BoundedFileReader.read(try file("empty.bin", Data()), max: 0).count, 0)
    }

    func testRefusesDirectoriesFifosAndMissingFilesWithoutBlocking() throws {
        XCTAssertThrowsError(try BoundedFileReader.read(dir, max: 1 << 20)) { e in
            XCTAssertEqual(e as? BoundedFileReader.Failure, .notRegularFile)
        }
        let fifo = dir.appendingPathComponent("pipe")
        XCTAssertEqual(mkfifo(fifo.path, 0o600), 0)
        let started = Date()
        XCTAssertThrowsError(try BoundedFileReader.read(fifo, max: 1 << 20)) { e in
            XCTAssertEqual(e as? BoundedFileReader.Failure, .notRegularFile)
        }
        XCTAssertLessThan(Date().timeIntervalSince(started), 2, "a FIFO with no writer must not block the open")
        XCTAssertThrowsError(try BoundedFileReader.read(dir.appendingPathComponent("missing"), max: 10)) { e in
            XCTAssertEqual(e as? BoundedFileReader.Failure, .cannotOpen(ENOENT))
        }
    }

    func testReadsAcrossChunkBoundaries() throws {
        var d = Data(count: (1 << 20) * 3 + 123)
        d.withUnsafeMutableBytes { for i in stride(from: 0, to: $0.count, by: 4097) { $0[i] = UInt8(i % 251) } }
        let u = try file("chunks.bin", d)
        XCTAssertEqual(try BoundedFileReader.read(u, max: d.count), d)
    }

    // MARK: FileImport

    func testTextFileBecomesATextItem() throws {
        let u = try file("note.txt", Data("héllo {date}\n".utf8))
        let (clip, outcome) = FileImport.clip(from: u)
        XCTAssertEqual(outcome, .text)
        XCTAssertEqual(clip.plainText, "héllo {date}\n")
        XCTAssertNoThrow(try Backup.validate(item: clip))
    }

    func testTextOverTheCeilingBecomesAReferenceNotAnItem() throws {
        let u = try file("huge.txt", Data(repeating: 0x61, count: Limits.textBytesCeiling + 1))
        let (clip, outcome) = FileImport.clip(from: u)
        XCTAssertEqual(outcome, .reference)
        XCTAssertEqual(clip.kind, .files)
        XCTAssertNil(clip.formats[ClipItem.Format.text])
        XCTAssertNoThrow(try Backup.validate(item: clip))
    }

    func testBinaryFileBecomesAReference() throws {
        let u = try file("blob.bin", Data([0xFF, 0xFE, 0x00, 0x01, 0x80]))
        XCTAssertEqual(FileImport.clip(from: u).1, .reference)
    }

    func testSmallImageBecomesPNG() throws {
        let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: 4, pixelsHigh: 3, bitsPerSample: 8, samplesPerPixel: 4,
                                   hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
        let tiff = rep.tiffRepresentation!
        let u = try file("pic.tiff", tiff)
        let (clip, outcome) = FileImport.clip(from: u)
        XCTAssertEqual(outcome, .image)
        XCTAssertTrue(ClipItem.isPNG(clip.formats[ClipItem.Format.png] ?? Data()))
        XCTAssertNoThrow(try Backup.validate(item: clip))
    }

    /// A PNG whose IHDR claims 30 000 × 30 000 — refused from the header, never decoded.
    func testImageBombIsRefusedBeforeDecoding() throws {
        var png = Data([0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A])
        func be32(_ v: UInt32) -> [UInt8] { [UInt8(v >> 24), UInt8((v >> 16) & 0xFF), UInt8((v >> 8) & 0xFF), UInt8(v & 0xFF)] }
        var ihdr: [UInt8] = Array("IHDR".utf8) + be32(30_000) + be32(30_000) + [8, 6, 0, 0, 0]
        png.append(contentsOf: be32(13)); png.append(contentsOf: ihdr)
        png.append(contentsOf: be32(crc32(ihdr)))
        png.append(contentsOf: be32(0)); png.append(contentsOf: Array("IEND".utf8)); png.append(contentsOf: be32(crc32(Array("IEND".utf8))))
        ihdr.removeAll()
        XCTAssertFalse(ClipItem.pixelCountOK(png))
        let u = try file("bomb.png", png)
        let (clip, outcome) = FileImport.clip(from: u)
        XCTAssertEqual(outcome, .reference)
        XCTAssertNil(clip.formats[ClipItem.Format.png])
    }

    func testGarbageWithAnImageExtensionBecomesAReference() throws {
        let u = try file("fake.png", Data(repeating: 0x00, count: 300))
        XCTAssertEqual(FileImport.clip(from: u).1, .reference)
    }

    private func crc32(_ bytes: [UInt8]) -> UInt32 {
        var table = [UInt32](repeating: 0, count: 256)
        for i in 0..<256 {
            var c = UInt32(i)
            for _ in 0..<8 { c = (c & 1) != 0 ? 0xEDB88320 ^ (c >> 1) : c >> 1 }
            table[i] = c
        }
        var crc: UInt32 = 0xFFFFFFFF
        for b in bytes { crc = table[Int((crc ^ UInt32(b)) & 0xFF)] ^ (crc >> 8) }
        return crc ^ 0xFFFFFFFF
    }
}
