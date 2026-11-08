import Foundation

/// Turning protection on, changing the password and turning protection off as one transaction
/// (3.0.6 security review, SEC01). Before it, `Vault.enable` wrote vault.json first and the data
/// files were re-saved afterwards one by one with their errors swallowed, and `disableProtection`
/// deleted vault.json before the plain files existed: a stop or a failure in between left
/// vault.json and the data under different keys, and the old password no longer opened the vault.
///
/// Here everything is prepared in memory — the new `Vault.Meta`, the data files sealed with the
/// new key (or plain) — and written through `RestoreCommit.writeFiles` on the `protection` journal:
/// previous bytes copied (vault.json included), marker, writes, marker removed (the commit point),
/// copies swept. A failure before the marker goes puts every file back; a stop in between is put
/// right by the launch replay before anything is read; after the marker is gone the caller
/// publishes the new key unconditionally. Nothing in memory changes in any failure case.
///
/// A data file Keepit could not read (held) is never part of this: the caller refuses the
/// operation while any is held, because re-keying around it would destroy the one way left to
/// decrypt it by hand (design review). History that is not kept on disk stays off disk
/// (`historyJSON` nil → the file is removed, as a restore does).
enum ProtectionCommit {
    struct Plan {
        /// vault.json's new bytes; nil removes the file (protection off).
        let meta: Data?
        /// The key the data files are sealed with; nil writes them plain (protection off).
        let key: SecureKey?
        let templatesJSON: Data
        let historyJSON: Data?
        let settingsJSON: Data
    }

    static let vaultName = "vault.json"

    static func steps(_ plan: Plan) throws -> [RestoreCommit.Step] {
        var steps = [RestoreCommit.Step(name: vaultName, url: Vault.metaURL, data: plan.meta, encrypt: false)]
        steps += try RestoreCommit.steps(templatesJSON: plan.templatesJSON, historyJSON: plan.historyJSON,
                                         settingsJSON: plan.settingsJSON, sealWith: plan.key)
        if plan.key == nil {
            // Plain on purpose: Storage.writeNow(encrypt: true) would seal with the key still in
            // memory. The settings step is plain already.
            steps = steps.map { RestoreCommit.Step(name: $0.name, url: $0.url, data: $0.data, encrypt: false) }
        }
        return steps
    }

    /// The transaction. Throws `RestoreCommit.Failure`; on return the new files are the state at
    /// the next launch, whatever happens afterwards.
    static func commit(_ plan: Plan) throws {
        try RestoreCommit.writeFiles(try steps(plan), journal: .protection)
    }
}
