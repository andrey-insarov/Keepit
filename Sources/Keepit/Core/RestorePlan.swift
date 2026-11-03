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

        var errorDescription: String? {
            switch self {
            case .locked: return L("Restore cancelled: Keepit was locked meanwhile.")
            case .cannotReadPrevious(let name, let e): return LF("Could not read the current %@ before replacing it: %@", name, e.localizedDescription)
            case .cannotJournal(let e): return LF("Could not prepare the undo copy of the current data: %@", e.localizedDescription)
            case .journalArmed: return L("An earlier restore could not be undone completely. Quit and launch Keepit again so it can finish putting the data back.")
            case .writeFailed(let name, let e): return LF("Could not write %@: %@ — the previous files were kept.", name, e.localizedDescription)
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

    static let names = ["templates.json", "history.json", "settings.json"]
    static var journalDirectory: URL { Storage.directory.appendingPathComponent("restore-journal", isDirectory: true) }
    static var journalMarker: URL { journalDirectory.appendingPathComponent("commit") }
    static func liveURL(_ name: String) -> URL { Storage.directory.appendingPathComponent(name) }
    /// True while an undo is unfinished: the files may be a mix and the journal is their only
    /// intact copy. Nothing may be saved over them until a replay succeeds.
    static var hasArmedJournal: Bool { FileManager.default.fileExists(atPath: journalMarker.path) }

    static func steps(templatesJSON: Data, historyJSON: Data?, settingsJSON: Data) -> [Step] {
        [Step(name: names[0], url: Storage.templatesURL, data: templatesJSON, encrypt: true),
         Step(name: names[1], url: Storage.historyURL, data: historyJSON, encrypt: true),
         Step(name: names[2], url: Storage.settingsURL, data: settingsJSON, encrypt: false)]
    }

    static func readPrevious(_ url: URL) throws -> Previous {
        guard FileManager.default.fileExists(atPath: url.path) else { return .absent }
        return .bytes(try Data(contentsOf: url))
    }

    /// Copy the previous bytes of every existing file into the journal, then arm it with the marker.
    /// Throws before anything is armed. The copies are read on `Storage.ioQueue`, behind every save
    /// queued so far, so the journal holds what the stores last wrote, not what was on disk a
    /// moment earlier; the commit's own writes go through the same queue afterwards. An unarmed
    /// journal (a crash while one was being written) is replaced; an armed one is never touched.
    static func writeJournal() throws {
        let fm = FileManager.default
        if fm.fileExists(atPath: journalMarker.path) { throw Failure.journalArmed }
        if fm.fileExists(atPath: journalDirectory.path) { try fm.removeItem(at: journalDirectory) }
        try fm.createDirectory(at: journalDirectory, withIntermediateDirectories: true)
        try Storage.ioQueue.sync {
            for name in names {
                switch try readPrevious(liveURL(name)) {
                case .absent: break
                case .bytes(let b): try b.write(to: journalDirectory.appendingPathComponent(name), options: .atomic)
                }
            }
            try Data("1".utf8).write(to: journalMarker, options: .atomic)
        }
    }

    /// Put every file back as the journal has it, then drop the journal. Idempotent. Errors are
    /// collected per file and returned, never swallowed; the journal stays when any remain.
    static func replayJournal() -> [(String, Error)] {
        let fm = FileManager.default
        var errors: [(String, Error)] = []
        for name in names {
            let copy = journalDirectory.appendingPathComponent(name)
            do {
                if fm.fileExists(atPath: copy.path) {
                    let bytes = try Data(contentsOf: copy)
                    // Already as it should be (the write never happened, or a previous replay got
                    // this far): leave it — a file that cannot be rewritten need not be.
                    if (try? Data(contentsOf: liveURL(name))) != bytes { try Storage.writeRawNow(bytes, to: liveURL(name)) }
                } else {
                    try Storage.removeNow(liveURL(name))
                }
            } catch { errors.append((name, error)) }
        }
        if errors.isEmpty {
            do { try fm.removeItem(at: journalMarker); try fm.removeItem(at: journalDirectory) }
            catch { errors.append(("restore-journal", error)) }
        }
        return errors
    }

    /// At launch, before any store is loaded. Returns true when a journal was replayed.
    /// An unarmed journal (no marker) is deleted: the commit never started.
    @discardableResult
    static func recoverIfNeeded() throws -> Bool {
        let fm = FileManager.default
        guard fm.fileExists(atPath: journalDirectory.path) else { return false }
        guard fm.fileExists(atPath: journalMarker.path) else { try fm.removeItem(at: journalDirectory); return false }
        let errors = replayJournal()
        if let first = errors.first { throw Failure.undoFailed("restore-journal", first.1, undo: errors) }
        return true
    }

    /// Write templates, history (nil → the file is removed) and settings, journaled: a failure of
    /// any write puts the previous files back (`replayJournal`) and names the file; a process
    /// killed in between is put right by `recoverIfNeeded` at the next launch. Nothing in memory
    /// has changed in any failure case.
    static func writeFiles(templatesJSON: Data, historyJSON: Data?, settingsJSON: Data) throws {
        try writeFiles(steps(templatesJSON: templatesJSON, historyJSON: historyJSON, settingsJSON: settingsJSON))
    }

    static func writeFiles(_ steps: [Step]) throws {
        for s in steps {
            do { _ = try readPrevious(s.url) } catch { throw Failure.cannotReadPrevious(s.name, error) }
        }
        do { try writeJournal() } catch let e as Failure { throw e } catch { throw Failure.cannotJournal(error) }
        for s in steps {
            do {
                if let data = s.data { try Storage.writeNow(data, to: s.url, encrypt: s.encrypt) }
                else { try Storage.removeNow(s.url) }
            } catch {
                let undo = replayJournal()
                if undo.isEmpty { throw Failure.writeFailed(s.name, error) }
                throw Failure.undoFailed(s.name, error, undo: undo)
            }
        }
        try clearJournal()
    }

    /// Marker first (disarms), then the copies.
    static func clearJournal() throws {
        let fm = FileManager.default
        if fm.fileExists(atPath: journalMarker.path) { try fm.removeItem(at: journalMarker) }
        if fm.fileExists(atPath: journalDirectory.path) { try fm.removeItem(at: journalDirectory) }
    }
}
