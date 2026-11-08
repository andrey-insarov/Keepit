import AppKit
import XCTest
@testable import Keepit

/// SEC07 — a keepit:// sender is trusted by its code-signing identity, evaluated by the Security
/// framework against Keepit's own requirement, never by a bundle identifier it claims
/// (`DESIGN-3.0.7.md`, SEC07). The real `SecCode` path runs on the test process itself; the trust
/// logic runs with injected identities through `urlCommandSenderForTesting`.
final class URLSenderIdentityTests: XCTestCase {
    var tmp: TempStorage!
    var confirmations = 0

    override func setUp() {
        tmp = TempStorage()
        confirmations = 0
        _ = NSApplication.shared
        Vault.errorSinkForTesting = { _ in }
    }
    override func tearDown() {
        CodeIdentity.validatesForTesting = nil
        Vault.errorSinkForTesting = nil
        Storage.clearKey()
        tmp.restore()
    }

    // MARK: the real Security framework, on this process

    func testTheTestProcessHasAnAppleIdentityAndFailsAnyTeamRequirement() throws {
        let me = try XCTUnwrap(CodeIdentity.read(pid: getpid()), "xctest is Apple-signed: it must have an identity")
        XCTAssertFalse(me.identifier.isEmpty)
        XCTAssertNil(me.teamID)
        XCTAssertTrue(me.isAppleHost, "Apple-signed, no Team ID: a script host, asked every time")
        // Keepit's requirement for a third-party app never validates against Apple's own code,
        // whatever identifier is written into it — the chain and the Team ID are the OS's to check.
        XCTAssertFalse(me.validates(TrustedSender(identifier: me.identifier, teamID: "ABCDE12345", displayName: "")))
        XCTAssertFalse(me.validates(TrustedSender(identifier: "com.example.other", teamID: "ABCDE12345", displayName: "")))
    }

    func testAGonePIDHasNoIdentity() {
        XCTAssertNil(CodeIdentity.read(pid: 999_999))
    }

    // MARK: the requirement is Keepit's, built from two checked facts

    func testTheRequirementTemplateNamesChainIdentifierAndTeam() throws {
        let text = try XCTUnwrap(CodeIdentity.requirementText(identifier: "com.raycast.macos", teamID: "SY64MV22J9"))
        XCTAssertTrue(text.hasPrefix("anchor apple generic and identifier \"com.raycast.macos\" and "))
        XCTAssertTrue(text.contains("certificate leaf[field.1.2.840.113635.100.6.1.9] exists"), "Mac App Store leaf")
        XCTAssertTrue(text.contains("certificate 1[field.1.2.840.113635.100.6.2.6] exists and certificate leaf[field.1.2.840.113635.100.6.1.13] exists"), "Developer ID CA and leaf, both")
        XCTAssertTrue(text.hasSuffix("certificate leaf[subject.OU] = \"SY64MV22J9\""))
        XCTAssertEqual(text.filter { $0 == "\"" }.count, 4, "exactly the two quoted literals")
    }

    func testIdentifierAndTeamIDOutsideTheSyntaxBuildNoRequirement() {
        XCTAssertNil(CodeIdentity.requirementText(identifier: "com.x\"; or anchor apple //", teamID: "ABCDE12345"), "a quote and requirement language")
        XCTAssertNil(CodeIdentity.requirementText(identifier: "com.x\\\"", teamID: "ABCDE12345"), "a backslash")
        XCTAssertNil(CodeIdentity.requirementText(identifier: "com.x y", teamID: "ABCDE12345"), "whitespace")
        XCTAssertNil(CodeIdentity.requirementText(identifier: ".com.x", teamID: "ABCDE12345"), "leading dot")
        XCTAssertNil(CodeIdentity.requirementText(identifier: String(repeating: "a", count: 256), teamID: "ABCDE12345"), "too long")
        XCTAssertNil(CodeIdentity.requirementText(identifier: "com.x", teamID: "abcde12345"), "lower-case Team ID")
        XCTAssertNil(CodeIdentity.requirementText(identifier: "com.x", teamID: "ABCDE1234"), "nine characters")
        XCTAssertNil(CodeIdentity.requirementText(identifier: "com.x", teamID: "ABCDE1234\""), "a quote")
        XCTAssertNotNil(CodeIdentity.requirementText(identifier: "com.example.My-App_2", teamID: "0123456789"))
        // A sender whose signing identifier is outside the syntax can never be trusted, Team ID or not.
        let crafted = URLSender(app: nil, identity: CodeIdentity(identifier: "com.x\"; or anchor apple //", teamID: "ABCDE12345", isAppleHost: false), isBrowser: false)
        XCTAssertNil(crafted.trustedEntry)
    }

    // MARK: the three classes of sender

    private func app() throws -> AppDelegate {
        let a = AppDelegate()
        a.loadStoresForTesting()
        a.createBackupEngine()
        var s = a.settings
        s.allowURLCommands = true
        s.pasteAfterSelect = false
        a.apply(settings: s)
        Storage.key = try Vault.enable(password: .of("test-only"), rounds: 1000)
        a.hotKeyFailureForTesting = { _ in }
        a.confirmURLCommandForTesting = { [unowned self] _ in self.confirmations += 1; return .allowAlways }
        return a
    }
    private func pause(_ a: AppDelegate) throws {
        a.handle(try XCTUnwrap(URL(string: "keepit://pause")))
    }
    private let raycast = CodeIdentity(identifier: "com.raycast.macos", teamID: "SY64MV22J9", isAppleHost: false)
    private let shortcuts = CodeIdentity(identifier: "com.apple.shortcuts", teamID: nil, isAppleHost: true)
    /// Stands for the Security framework: an entry validates iff identifier and Team ID are the sender's.
    private func installFakeValidation() {
        CodeIdentity.validatesForTesting = { identity, entry in identity.identifier == entry.identifier && identity.teamID == entry.teamID }
    }

    func testAThirdPartyAppIsAskedOnceThenTrustedByIdentity() throws {
        installFakeValidation()
        let a = try app()
        a.urlCommandSenderForTesting = URLSender(app: nil, identity: raycast, isBrowser: false)
        try pause(a)
        XCTAssertEqual(confirmations, 1)
        XCTAssertNotNil(a.pausedUntil, "ran after Always Allow")
        XCTAssertEqual(a.settings.trustedURLSenderIdentities, [TrustedSender(identifier: "com.raycast.macos", teamID: "SY64MV22J9", displayName: "com.raycast.macos")])
        try pause(a)
        XCTAssertEqual(confirmations, 1, "trusted: no dialog")
        XCTAssertNotNil(a.pausedUntil)
    }

    func testAnAppClaimingATrustedBundleIdentifierUnderAnotherTeamIsAsked() throws {
        installFakeValidation()
        let a = try app()
        var s = a.settings; s.trustedURLSenderIdentities = [TrustedSender(identifier: "com.raycast.macos", teamID: "SY64MV22J9", displayName: "Raycast")]; a.apply(settings: s)
        a.urlCommandSenderForTesting = URLSender(app: nil, identity: CodeIdentity(identifier: "com.raycast.macos", teamID: "EVIL000000", isAppleHost: false), isBrowser: false)
        a.confirmURLCommandForTesting = { [unowned self] _ in self.confirmations += 1; return .deny }
        try pause(a)
        XCTAssertEqual(confirmations, 1, "the requirement names the Team ID: another team is another program")
        XCTAssertNil(a.pausedUntil)
        // Unsigned under the same bundle identifier: no identity at all.
        a.urlCommandSenderForTesting = URLSender(app: nil, identity: nil, isBrowser: false)
        try pause(a)
        XCTAssertEqual(confirmations, 2)
    }

    func testAnAppleScriptHostIsAskedEveryTimeAndNeverListed() throws {
        installFakeValidation()
        let a = try app()
        a.urlCommandSenderForTesting = URLSender(app: nil, identity: shortcuts, isBrowser: false)
        XCTAssertTrue(a.urlCommandSenderForTesting!.needsConfirmation)
        XCTAssertFalse(a.urlCommandSenderForTesting!.canBeTrusted)
        try pause(a)
        try pause(a)
        XCTAssertEqual(confirmations, 2, "each time")
        XCTAssertTrue(a.settings.trustedURLSenderIdentities.isEmpty, "Always Allow for a host adds nothing")
        XCTAssertNotNil(a.pausedUntil, "but Allow runs the command")
    }

    func testABrowserAndAnUnidentifiedSenderAreAskedEveryTime() throws {
        installFakeValidation()
        let a = try app()
        a.urlCommandSenderForTesting = URLSender(app: nil, identity: raycast, isBrowser: true)
        try pause(a); try pause(a)
        XCTAssertEqual(confirmations, 2)
        a.urlCommandSenderForTesting = URLSender(app: nil, identity: nil, isBrowser: false)
        try pause(a)
        XCTAssertEqual(confirmations, 3)
        XCTAssertTrue(a.settings.trustedURLSenderIdentities.isEmpty)
    }

    func testTrustIsEvaluatedNotCompared() throws {
        // The fake framework says "no" to everything: a matching entry in the list is not enough.
        CodeIdentity.validatesForTesting = { _, _ in false }
        let a = try app()
        var s = a.settings; s.trustedURLSenderIdentities = [TrustedSender(identifier: "com.raycast.macos", teamID: "SY64MV22J9", displayName: "Raycast")]; a.apply(settings: s)
        a.urlCommandSenderForTesting = URLSender(app: nil, identity: raycast, isBrowser: false)
        a.confirmURLCommandForTesting = { [unowned self] _ in self.confirmations += 1; return .deny }
        try pause(a)
        XCTAssertEqual(confirmations, 1, "Keepit compares no strings; the framework decides")
    }

    // MARK: the settings file

    func testTheLegacyBundleIdListIsIgnoredAndEmptied() throws {
        let json = Data("""
        {"allowURLCommands": true, "trustedURLSenders": ["com.raycast.macos", "com.apple.shortcuts"]}
        """.utf8)
        let s = try Storage.decoder.decode(Settings.self, from: json)
        XCTAssertTrue(s.allowURLCommands)
        XCTAssertTrue(s.trustedURLSenderIdentities.isEmpty, "a bundle id is a claim: not carried over")
        let out = try XCTUnwrap(try JSONSerialization.jsonObject(with: Storage.encoder.encode(s)) as? [String: Any])
        XCTAssertEqual(out["trustedURLSenders"] as? [String], [], "written back empty")
        XCTAssertEqual((out["trustedURLSenderIdentities"] as? [Any])?.count, 0)
    }

    func testTheNewListRoundTripsAndDropsEntriesOutsideTheSyntax() throws {
        var s = Settings()
        s.trustedURLSenderIdentities = [
            TrustedSender(identifier: "com.raycast.macos", teamID: "SY64MV22J9", displayName: "Raycast"),
            TrustedSender(identifier: "com.x\"; or anchor apple //", teamID: "ABCDE12345", displayName: "crafted"),
            TrustedSender(identifier: "com.y", teamID: "short", displayName: "crafted"),
        ]
        let back = try Storage.decoder.decode(Settings.self, from: Storage.encoder.encode(s))
        XCTAssertEqual(back.trustedURLSenderIdentities.map(\.identifier), ["com.raycast.macos"], "decoding clamps: what no requirement can be built from is dropped")
    }

    func testTrustNeverLeavesOrEntersThroughABackup() {
        var mine = Settings()
        mine.trustedURLSenderIdentities = [TrustedSender(identifier: "com.raycast.macos", teamID: "SY64MV22J9", displayName: "Raycast")]
        XCTAssertTrue(mine.forBackup.trustedURLSenderIdentities.isEmpty, "not in a backup")
        var theirs = Settings()
        theirs.trustedURLSenderIdentities = [TrustedSender(identifier: "com.evil", teamID: "EVIL000000", displayName: "Evil")]
        XCTAssertEqual(mine.applyingRestorable(from: theirs).trustedURLSenderIdentities, mine.trustedURLSenderIdentities, "a restore keeps the local list")
    }

    func testSenderDescriptionsCarryTheTeamID() {
        let s = URLSender(app: nil, identity: raycast, isBrowser: false)
        XCTAssertEqual(s.displayName, "com.raycast.macos (Team ID SY64MV22J9)")
        XCTAssertEqual(s.trustedEntry?.teamID, "SY64MV22J9")
        XCTAssertEqual(URLSender.pid(of: Data(repeating: 0, count: MemoryLayout<audit_token_t>.size)), 0)
    }
}
