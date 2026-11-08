import Foundation

/// Everything a restore will change, computed and checked *before* any store is touched —
/// docs/BACKUP.md "Apply as one transaction". Pure: no AppKit, no disk, no store mutation, so the
/// rules are unit-tested directly and committing is a handful of writes and assignments.
///
/// Rules:
/// - The final settings come first. When preferences are restored, the backup's settings (minus the
///   keys `applyingRestorable` keeps local) are what the history is trimmed by — restoring 3 items
///   together with `historyMax = 3` keeps 3, whatever the limit was before.
/// - Merge keeps the current items newest and appends backup items whose `contentHash` is not
///   present. Appended items get fresh ids: the backup may be this Mac's own, and an item edited
///   here since then would otherwise come back under an id already in use — which the next
///   backup's validator rejects.
/// - Merge adds the backup's template tree as one new top-level folder, deep-copied with fresh ids
///   and without hot keys (a copy of a template never inherits its key, same as drag-copy), to a
///   clone of the current tree. The composed tree is checked against the count and depth ceilings
///   here; if it does not fit, nothing fits.
/// - Replace takes the backup's history and template tree as they are (ids, hot keys), trimmed by
///   the final settings. The payload was validated when it was opened.
///
/// The plan is the complete next state — settings, history, template root — and shares no node
/// with the live stores, so it can be dropped without a trace, or written to disk as one commit and
/// only then assigned (`AppDelegate.commit(_:)`). It describes the stores *as they were when it was
/// made*: the caller compares the stores' revisions before committing and plans again if they moved.
struct RestorePlan {
    enum Mode { case merge, replace }

    enum Failure: LocalizedError, Equatable {
        case templateLimit
        var errorDescription: String? {
            switch self {
            case .templateLimit:
                return LF("Limit reached: at most %d template items, %d levels deep.", Limits.templateMaxCount, Limits.templateMaxDepth)
            }
        }
    }

    let mode: Mode
    /// The settings in force after the restore (the current ones unless preferences are restored).
    let settings: Settings
    /// The complete history after the restore, newest first, trimmed by `settings`.
    let history: [ClipItem]
    /// The complete template tree after the restore; no node in common with the live tree.
    let templates: TemplateNode
    /// Backup items that are in `history` (Merge: the ones that were not already present).
    let historyAdded: Int
    /// Backup items that were new but did not fit the final limits.
    let historyDropped: Int
    /// Template nodes (items and folders) the restore adds.
    let templatesAdded: Int

    static func make(mode: Mode, payload: Backup.Payload,
                     currentHistory: [ClipItem], currentTemplates: TemplateNode, currentSettings: Settings,
                     restorePreferences: Bool, folderName: String, now: Date = Date()) throws -> RestorePlan {
        var settings = currentSettings
        if restorePreferences, let s = payload.settings {
            settings = currentSettings.applyingRestorable(from: s)
            settings.clamp()
        }

        let candidate: [ClipItem]
        let fresh: Int
        let templates: TemplateNode
        let templatesAdded: Int
        switch mode {
        case .replace:
            candidate = payload.history
            fresh = candidate.count
            templates = payload.templates.clone()
            templatesAdded = payload.templates.subtreeCount - 1
        case .merge:
            var seen = Set(currentHistory.map(\.contentHash))
            var added: [ClipItem] = []
            for it in payload.history where !seen.contains(it.contentHash) {
                seen.insert(it.contentHash)
                added.append(it.withNewID())
            }
            candidate = currentHistory + added
            fresh = added.count
            let copy = payload.templates.duplicate()           // fresh ids, no hot keys
            let folder = TemplateNode(name: String(folderName.prefix(Limits.templateNameMaxChars)), children: copy.children)
            let root = currentTemplates.clone()                // same ids, no node shared with the live tree
            root.insert(folder)
            // The validator's rule for what may be stored: count ≤ max, deepest node ≤ max (root is 0).
            guard root.subtreeCount <= Limits.templateMaxCount,
                  root.height <= Limits.templateMaxDepth else { throw Failure.templateLimit }
            templates = root
            templatesAdded = folder.subtreeCount
        }

        let final = HistoryStore.trimmed(candidate, settings: settings, now: now)
        let finalIDs = Set(final.map(\.id))
        let keptFresh: Int
        switch mode {
        case .replace: keptFresh = final.count
        case .merge: keptFresh = candidate.suffix(fresh).filter { finalIDs.contains($0.id) }.count
        }
        return RestorePlan(mode: mode, settings: settings, history: final, templates: templates,
                           historyAdded: keptFresh, historyDropped: fresh - keptFresh, templatesAdded: templatesAdded)
    }

}

extension ClipItem {
    /// The same content under a new local id.
    func withNewID() -> ClipItem {
        ClipItem(id: UUID(), date: date, formats: formats, sourceApp: sourceApp, contentHash: contentHash)
    }
}

/// The disk half of a restore: the three files written in one go, or none of them — across a
/// failed write *and* across a process killed between the writes.
///
/// Journal: before the first write, the previous bytes of every existing file are copied into
/// `restore-journal/` and a marker `commit` is written last. Then the three files are written.
/// Then the marker is removed, then the journal. At launch (`recoverIfNeeded`, before any store is
/// loaded) a journal with the marker is replayed — every copied file put back, every file that had
/// no copy removed — and only then deleted; a journal without the marker was never armed and is
/// simply deleted. Replay is idempotent, so a crash during replay is replayed again next time.
/// A failed write uses the same replay as its undo. `AppDelegate.commit(_:)` calls `writeFiles`
/// first and assigns the live stores only when it returned.
enum RestoreCommit {
    enum Failure: LocalizedError {
        case locked
        /// The files were written and then Keepit was locked before the models were published:
        /// the stores stay purged and load the files on unlock. Not a failure of the restore.
        case lockedAfterWrite
        /// An existing file could not be read before the first write; nothing was written.
        case cannotReadPrevious(String, Error)
        /// The journal could not be written; nothing was written.
        case cannotJournal(Error)
        /// An armed journal is on disk: a previous restore's undo did not finish. It is never
        /// discarded by a new commit — the launch replay owns it.
        case journalArmed
        /// A write failed and the files written before it were put back.
        case writeFailed(String, Error)
        /// A write failed and putting a previous file back failed too: the data directory needs
        /// a look (the file is named). The journal stays, so the next launch tries again.
        case undoFailed(String, Error, undo: [(String, Error)])
        /// The bytes to write are larger than the reader's limit: the next launch could not open
        /// the file. Nothing was written.
        case tooLarge(String)

        var errorDescription: String? {
            switch self {
            case .locked: return L("Restore cancelled: Keepit was locked meanwhile.")
            case .lockedAfterWrite: return L("Keepit was locked during the restore. The restored data is on disk and is loaded when you unlock.")
            case .cannotReadPrevious(let name, let e): return LF("Could not read the current %@ before replacing it: %@", name, e.localizedDescription)
            case .cannotJournal(let e): return LF("Could not prepare the undo copy of the current data: %@", e.localizedDescription)
            case .journalArmed: return L("An earlier restore could not be undone completely. Quit and launch Keepit again so it can finish putting the data back.")
            case .writeFailed(let name, let e): return LF("Could not write %@: %@ — the previous files were kept.", name, e.localizedDescription)
            case .tooLarge(let name): return LF("%@ would be larger than Keepit can read back. Lower the limits in Settings → History first.", name)
            case .undoFailed(let name, let e, let undo):
                let list = undo.map { "\($0.0): \($0.1.localizedDescription)" }.joined(separator: "; ")
                return LF("Could not write %@: %@ — and putting the previous files back failed too (%@). Check the data folder before going on.", name, e.localizedDescription, list)
            }
        }
    }

    /// What was on disk before the commit: a missing file is not the same as one that could not be read.
    enum Previous { case absent, bytes(Data) }

    struct Step {
        let name: String
        let url: URL
        let data: Data?       // nil: the file is removed (history not kept on disk)
        let encrypt: Bool
    }

    static let names = FileJournal.restore.names
    static var journalDirectory: URL { FileJournal.restore.directory }
    static var journalMarker: URL { FileJournal.restore.marker }
    static func liveURL(_ name: String) -> URL { Storage.directory.appendingPathComponent(name) }
    /// True while an undo is unfinished: the files may be a mix and the journal is their only
    /// intact copy. Nothing may be saved over them until a replay succeeds. Either journal counts.
    static var hasArmedJournal: Bool { FileJournal.restore.isArmed || FileJournal.protection.isArmed }

    /// `sealWith`: a key the data files are sealed with *here*, when it is not (yet) `Storage.key` —
    /// a restore that creates the vault in the same commit. Otherwise `Storage.writeNow` seals with
    /// the current key.
    static func steps(templatesJSON: Data, historyJSON: Data?, settingsJSON: Data, sealWith key: SecureKey? = nil) throws -> [Step] {
        func seal(_ d: Data?) throws -> Data? { guard let d else { return nil }; return key.map { try Vault.encrypt(d, key: $0) } ?? d }
        return [Step(name: names[0], url: Storage.templatesURL, data: try seal(templatesJSON), encrypt: key == nil),
                Step(name: names[1], url: Storage.historyURL, data: try seal(historyJSON), encrypt: key == nil),
                Step(name: names[2], url: Storage.settingsURL, data: settingsJSON, encrypt: false)]
    }

    static func readPrevious(_ url: URL) throws -> Previous { try FileJournal.readPrevious(url) }

    static func writeJournal() throws { try FileJournal.restore.write() }
    static func replayJournal() -> [(String, Error)] { FileJournal.restore.replay() }

    /// At launch, before any store is loaded: both journals (at most one can be armed). Returns
    /// true when a journal was replayed. An unarmed journal (no marker) is deleted: the commit never
    /// started, or it finished and only the sweep was missed.
    @discardableResult
    static func recoverIfNeeded() throws -> Bool {
        let a = try FileJournal.restore.recoverIfNeeded()
        let b = try FileJournal.protection.recoverIfNeeded()
        return a || b
    }

    /// Write templates, history (nil → the file is removed) and settings, journaled: a failure of
    /// any write puts the previous files back (`replayJournal`) and names the file; a process
    /// killed in between is put right by `recoverIfNeeded` at the next launch. Nothing in memory
    /// has changed in any failure case.
    static func writeFiles(templatesJSON: Data, historyJSON: Data?, settingsJSON: Data) throws {
        try writeFiles(try steps(templatesJSON: templatesJSON, historyJSON: historyJSON, settingsJSON: settingsJSON), journal: .restore)
    }

    /// Tests only: runs after every file is written and before the marker goes (a disk that fails
    /// at the commit point).
    static var beforeDisarmForTesting: (() -> Void)?

    /// The commit: journal → writes → **disarm** (the marker goes: this is the commit point) → sweep.
    /// After this returns, the new files are the state at the next launch whatever else fails;
    /// the caller publishes the new state in memory unconditionally (3.0.6 design review of SEC01:
    /// an error after the marker is gone must not leave the old key in memory over new files).
    /// A failed disarm is undone like a failed write; a failed sweep is logged, and the next launch
    /// deletes the unarmed leftovers.
    static func writeFiles(_ steps: [Step], journal: FileJournal) throws {
        // A held file (one Keepit could not read) is never replaced by a commit: the caller sets
        // it aside first (Replace) or does not get here (Merge). Refused before anything is
        // journalled or written.
        for s in steps where Storage.isHeld(s.url) {
            throw Failure.cannotReadPrevious(s.name, Storage.Failure.held(s.url.lastPathComponent))
        }
        for s in steps {
            do { _ = try readPrevious(s.url) } catch { throw Failure.cannotReadPrevious(s.name, error) }
            if let d = s.data, d.count > Limits.dataFileMaxBytes { throw Failure.tooLarge(s.name) }   // the next launch could not read it back
        }
        if hasArmedJournal { throw Failure.journalArmed }
        do { try journal.write() } catch let e as Failure { throw e } catch { throw Failure.cannotJournal(error) }
        for s in steps {
            do {
                if let data = s.data { try Storage.writeNow(data, to: s.url, encrypt: s.encrypt) }
                else { try Storage.removeNow(s.url) }
            } catch {
                let undo = journal.replay()
                if undo.isEmpty { throw Failure.writeFailed(s.name, error) }
                throw Failure.undoFailed(s.name, error, undo: undo)
            }
        }
        beforeDisarmForTesting?()
        do { try journal.disarm() } catch {
            let undo = journal.replay()
            if undo.isEmpty { throw Failure.writeFailed("commit", error) }
            throw Failure.undoFailed("commit", error, undo: undo)
        }
        journal.sweep()
    }

    /// Marker first (disarms), then the copies. Kept for callers that clear by hand (tests).
    static func clearJournal() throws { try FileJournal.restore.disarm(); try FileJournal.restore.sweepOrThrow() }
}

/// A journal for one set of files: their previous bytes in a directory, armed by a marker. Two
/// exist — `restore` (templates, history, settings; the format 3.0.4–3.0.5 wrote, so an armed one
/// left by an older version is replayed exactly as before) and `protection` (the same plus
/// `vault.json`, for turning protection on or off and changing the password). At most one is
/// armed at a time (`RestoreCommit.hasArmedJournal` checks both before a commit); at launch both
/// are replayed if armed. Adding `vault.json` to the restore journal instead would have made an
/// old armed journal — which never recorded the vault — delete an existing vault on replay
/// (design review of SEC01).
struct FileJournal {
    let directory: URL
    let names: [String]

    static var restore: FileJournal {
        FileJournal(directory: Storage.directory.appendingPathComponent("restore-journal", isDirectory: true),
                    names: ["templates.json", "history.json", "settings.json"])
    }
    static var protection: FileJournal {
        FileJournal(directory: Storage.directory.appendingPathComponent("protection-journal", isDirectory: true),
                    names: ["vault.json", "templates.json", "history.json", "settings.json"])
    }

    var marker: URL { directory.appendingPathComponent("commit") }
    var isArmed: Bool { FileManager.default.fileExists(atPath: marker.path) }
    func liveURL(_ name: String) -> URL { Storage.directory.appendingPathComponent(name) }

    static func readPrevious(_ url: URL) throws -> RestoreCommit.Previous {
        guard FileManager.default.fileExists(atPath: url.path) else { return .absent }
        return .bytes(try BoundedFileReader.read(url, max: Limits.dataFileMaxBytes))
    }

    /// Copy the previous bytes of every existing file into the journal, then arm it with the marker.
    /// Throws before anything is armed. The copies are read on `Storage.ioQueue`, behind every save
    /// queued so far, so the journal holds what the stores last wrote, not what was on disk a
    /// moment earlier; the commit's own writes go through the same queue afterwards. An unarmed
    /// journal (a crash while one was being written) is replaced; an armed one is never touched.
    func write() throws {
        let fm = FileManager.default
        if isArmed { throw RestoreCommit.Failure.journalArmed }
        if fm.fileExists(atPath: directory.path) { try fm.removeItem(at: directory) }
        try fm.createDirectory(at: directory, withIntermediateDirectories: true)
        try Storage.ioQueue.sync {
            for name in names {
                switch try Self.readPrevious(liveURL(name)) {
                case .absent: break
                case .bytes(let b): try b.write(to: directory.appendingPathComponent(name), options: .atomic)
                }
            }
            try Data("1".utf8).write(to: marker, options: .atomic)
        }
    }

    /// Put every file back as the journal has it, then drop the journal. Idempotent. Errors are
    /// collected per file and returned, never swallowed; the journal stays when any remain.
    func replay() -> [(String, Error)] {
        let fm = FileManager.default
        var errors: [(String, Error)] = []
        for name in names {
            let copy = directory.appendingPathComponent(name)
            do {
                if fm.fileExists(atPath: copy.path) {
                    let bytes = try BoundedFileReader.read(copy, max: Limits.dataFileMaxBytes)
                    // Already as it should be (the write never happened, or a previous replay got
                    // this far): leave it — a file that cannot be rewritten need not be.
                    if (try? BoundedFileReader.read(liveURL(name), max: Limits.dataFileMaxBytes)) != bytes { try Storage.writeRawNow(bytes, to: liveURL(name)) }
                } else {
                    try Storage.removeNow(liveURL(name))
                }
            } catch { errors.append((name, error)) }
        }
        if errors.isEmpty {
            do { try fm.removeItem(at: marker); try fm.removeItem(at: directory) }
            catch { errors.append(("journal", error)) }
        }
        return errors
    }

    /// At launch, before any store is loaded. Returns true when the journal was replayed.
    /// An unarmed journal (no marker) is deleted: the commit never started, or finished.
    @discardableResult
    func recoverIfNeeded() throws -> Bool {
        let fm = FileManager.default
        guard fm.fileExists(atPath: directory.path) else { return false }
        guard isArmed else { try fm.removeItem(at: directory); return false }
        let errors = replay()
        if let first = errors.first { throw RestoreCommit.Failure.undoFailed(directory.lastPathComponent, first.1, undo: errors) }
        return true
    }

    /// The commit point: the marker goes. Throws if it cannot.
    func disarm() throws {
        let fm = FileManager.default
        if fm.fileExists(atPath: marker.path) { try fm.removeItem(at: marker) }
    }

    /// Cleanup after `disarm`: the copies. A failure here changes nothing about the commit; it is
    /// logged, and the next launch removes the unarmed directory.
    func sweep() {
        do { try sweepOrThrow() } catch { Log.storage.error("journal copies not removed: \(error.localizedDescription)") }
    }

    func sweepOrThrow() throws {
        let fm = FileManager.default
        if fm.fileExists(atPath: directory.path) { try fm.removeItem(at: directory) }
    }
}
