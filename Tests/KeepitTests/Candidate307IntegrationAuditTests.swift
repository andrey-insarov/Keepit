import AppKit
import XCTest
@testable import Keepit

/// The auditor's whole-tree checks of the 3.0.7 candidate (b5e5339), kept as regression tests: the four
/// deferred report queues re-check the lock together, the deferred size report must not promise what
/// lock/purge/reload has already discarded (P3), the Russian Advanced pane fits its trust button, and
/// the files the candidate writes open with the 3.0.6 reader (that check runs against the 3.0.6 tag
/// outside this suite; the producer here only writes the fixtures when KEEPIT_AUDIT_INTEROP_DIR is set).
final class Candidate307IntegrationAuditTests: XCTestCase {
    var tmp: TempStorage!
    override func setUp() { tmp = TempStorage(); _ = NSApplication.shared }
    override func tearDown() {
        Storage.fileLimitForTesting = nil
        Storage.onWriteRefused = nil
        Vault.errorSinkForTesting = nil
        Vault.promptForTesting = nil
        Storage.clearKey()
        tmp.restore()
    }
    private func drain() {
        let done = expectation(description: "deferred main-queue reports")
        DispatchQueue.main.async { DispatchQueue.main.async { DispatchQueue.main.async { done.fulfill() } } }
        wait(for: [done], timeout: 3)
    }
    private func appWithVault() throws -> AppDelegate {
        Storage.key = try Vault.enable(password: .of("audit-only-password"), rounds: 1000)
        let app = AppDelegate()
        app.loadStoresForTesting()
        app.createBackupEngine()
        app.hotKeyFailureForTesting = { _ in }
        Vault.promptForTesting = { _ in .password(.of("audit-only-password")) }
        return app
    }

    func testCandidateProducesManualAutomaticAndDataFileCompatibilityFixtures() throws {
        guard let path = ProcessInfo.processInfo.environment["KEEPIT_AUDIT_INTEROP_DIR"] else {
            throw XCTSkip("set KEEPIT_AUDIT_INTEROP_DIR to write the fixtures for the 3.0.6 reader check")
        }
        let dir = URL(fileURLWithPath: path, isDirectory: true)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        var binary = ClipItem.text("binary interop / unicode Привет 😀")
        binary.formats["com.example.opaque"] = Data(repeating: 0xff, count: 6000)
        binary.sourceApp = "com.example.compatibility"
        let root = TemplateNode(name: "Template", children: [TemplateNode(name: "Interop", text: "Hello / {cursor}")])
        var payload = Backup.Payload(history: [binary], templates: root, settings: Settings().forBackup)
        payload.app = "Keepit 3.0.7"
        let manual = try Backup.encode(payload, password: .of("interop-only-password"))
        try manual.write(to: dir.appendingPathComponent("manual-307.keepit"))
        try Storage.encoder.encode([binary]).write(to: dir.appendingPathComponent("history-307.json"))
        let key = try Vault.enable(password: .of("interop-only-password"), rounds: 1000)
        Storage.key = key
        let header = try XCTUnwrap(Vault.backupHeader(app: "Keepit 3.0.7", sourceID: UUID().uuidString.lowercased(), backupID: UUID().uuidString.lowercased()))
        let automatic = try Backup.encodeAutomatic(payload, dataKey: key, vault: header)
        try automatic.write(to: dir.appendingPathComponent("automatic-307.keepit"))
        XCTAssertEqual(try Backup.decode(manual, password: .of("interop-only-password")).history.first?.formats, binary.formats)
        XCTAssertEqual(try Backup.decode(automatic, password: .of("interop-only-password")).history.first?.formats, binary.formats)
    }

    func testCandidateDeferredReportsRecheckLockAcrossAllFourQueues() throws {
        let app = try appWithVault()
        defer { app.hotKeys.unregisterAll(); app.monitor.stop() }
        var seen: [String] = []
        Vault.errorSinkForTesting = { text in
            seen.append(text)
            if seen.count == 1 { app.lock() }
        }
        app.infoSinkForTesting = { seen.append($0) }
        let e = NSError(domain: NSPOSIXErrorDomain, code: Int(EACCES))
        app.unsweptToReport = [(FileJournal.protection.directory, e)]
        app.phraseNotConfirmed = true
        app.historyRemovalToReport = e
        app.refusedWritesToReport = ["templates.json"]
        app.lock()
        XCTAssertTrue(app.unlock())
        drain()
        XCTAssertTrue(app.isLocked)
        XCTAssertEqual(seen.count, 1, "a lock inside the first alert leaves the three other report types deferred")
        XCTAssertTrue(app.phraseNotConfirmed)
        XCTAssertNotNil(app.historyRemovalToReport)
        XCTAssertEqual(app.refusedWritesToReport, ["templates.json"])
        Vault.errorSinkForTesting = { seen.append($0) }
        XCTAssertTrue(app.unlock())
        drain()
        XCTAssertEqual(seen.count, 4, "every remaining report once")
        XCTAssertFalse(app.phraseNotConfirmed)
        XCTAssertNil(app.historyRemovalToReport)
        XCTAssertTrue(app.refusedWritesToReport.isEmpty)
    }

    func testCandidateDeferredSizeErrorMustNotClaimThePurgedEditRemainsInMemory() throws {
        let app = try appWithVault()
        defer { app.hotKeys.unregisterAll(); app.monitor.stop() }
        app.templates.replaceRoot(TemplateNode(name: "Template", children: [TemplateNode(name: "saved", text: "saved")]))
        app.templates.saveNow()
        Storage.fileLimitForTesting = 1024
        let pending = TemplateNode(name: "unsaved", text: String(repeating: "x", count: 2048))
        XCTAssertTrue(app.templates.insert(pending, under: app.templates.root))
        var reports: [String] = []
        Vault.errorSinkForTesting = { reports.append($0) }
        app.lock()                                  // flush refuses the oversized tree, then purge drops it
        drain()
        XCTAssertTrue(reports.isEmpty, "report waits until unlock")
        XCTAssertTrue(app.unlock())
        drain()
        XCTAssertEqual(app.templates.allItems().map(\.name), ["saved"], "the unsaved edit is gone after reload")
        let report = try XCTUnwrap(reports.first)
        XCTAssertTrue(report.contains("templates.json"))
        XCTAssertFalse(report.contains("nothing is lost in memory"), "this claim is false after lock/purge/reload already discarded the unsaved edit")
        XCTAssertTrue(report.contains("without the latest changes"), "the report says only what holds in both cases: the previous file is kept, the latest changes are not in it")
    }

    func testCandidateRussianAdvancedPaneShowsTrustControlsWithoutClipping() throws {
        guard L("Forget Trusted Apps (%d)") == "Забыть доверенные приложения (%d)" else { throw XCTSkip("run this test with -AppleLanguages (ru)") }
        let old = UserDefaults.standard.object(forKey: "SettingsWindow.pane")
        defer { if let old { UserDefaults.standard.set(old, forKey: "SettingsWindow.pane") } else { UserDefaults.standard.removeObject(forKey: "SettingsWindow.pane") } }
        UserDefaults.standard.set("advanced", forKey: "SettingsWindow.pane")
        let app = try appWithVault()
        var settings = app.settings
        settings.trustedURLSenderIdentities = (0 ..< 3).map { TrustedSender(identifier: "com.example.audit\($0)", teamID: "AUDIT00000", displayName: "Приложение \($0)") }
        app.apply(settings: settings)
        let controller = SettingsWindowController(app: app)
        let window = try XCTUnwrap(controller.window)
        defer { window.close(); app.hotKeys.unregisterAll(); app.monitor.stop() }
        window.layoutIfNeeded()
        let view = try XCTUnwrap(window.contentView)
        view.layoutSubtreeIfNeeded()
        func descendants(_ v: NSView) -> [NSView] { [v] + v.subviews.flatMap(descendants) }
        let button = try XCTUnwrap(descendants(view).compactMap { $0 as? NSButton }.first { $0.title == "Забыть доверенные приложения (3)" })
        XCTAssertGreaterThanOrEqual(button.bounds.width + 1, button.intrinsicContentSize.width)
        let rect = view.convert(button.bounds, from: button)
        XCTAssertGreaterThanOrEqual(rect.minX, -1)
        XCTAssertLessThanOrEqual(rect.maxX, view.bounds.maxX + 1)
        print("Russian Advanced pane: \(button.title), width=\(button.bounds.width), needed=\(button.intrinsicContentSize.width)")
    }
}
