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
                  Self.height(of: root) <= Limits.templateMaxDepth else { throw Failure.templateLimit }
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

    /// Levels below `node` (0 for a leaf or an empty folder).
    static func height(of node: TemplateNode) -> Int {
        node.children.reduce(0) { max($0, 1 + height(of: $1)) }
    }
}

extension ClipItem {
    /// The same content under a new local id.
    func withNewID() -> ClipItem {
        ClipItem(id: UUID(), date: date, formats: formats, sourceApp: sourceApp, contentHash: contentHash)
    }
}

/// The disk half of a restore: the three files written in one go, or none of them.
/// `AppDelegate.commit(_:)` calls this first and assigns the live stores only when it returned.
enum RestoreCommit {
    enum Failure: LocalizedError {
        case locked
        /// An existing file could not be read before the first write; nothing was written.
        case cannotReadPrevious(String, Error)
        /// A write failed and the files written before it were put back.
        case writeFailed(String, Error)
        /// A write failed and putting a previous file back failed too: the data directory needs
        /// a look (the file is named). Nothing in memory has changed; the next launch reloads
        /// whatever is on disk.
        case undoFailed(String, Error, undo: [(String, Error)])

        var errorDescription: String? {
            switch self {
            case .locked: return L("Restore cancelled: Keepit was locked meanwhile.")
            case .cannotReadPrevious(let name, let e): return LF("Could not read the current %@ before replacing it: %@", name, e.localizedDescription)
            case .writeFailed(let name, let e): return LF("Could not write %@: %@ — the previous files were kept.", name, e.localizedDescription)
            case .undoFailed(let name, let e, let undo):
                let list = undo.map { "\($0.0): \($0.1.localizedDescription)" }.joined(separator: "; ")
                return LF("Could not write %@: %@ — and putting the previous files back failed too (%@). Check the data folder before going on.", name, e.localizedDescription, list)
            }
        }
    }

    /// What was on disk before the commit: a missing file is not the same as one that could not be read.
    enum Previous { case absent, bytes(Data) }

    static func readPrevious(_ url: URL) throws -> Previous {
        guard FileManager.default.fileExists(atPath: url.path) else { return .absent }
        return .bytes(try Data(contentsOf: url))
    }

    /// Write templates, history (nil → the file is removed: history is not kept on disk) and
    /// settings. Before the first write, every existing file is read in full; a read failure
    /// cancels the commit untouched. If a write fails, the files written so far are put back to
    /// their previous bytes (or removed, when there was none); a failure of that undo is reported
    /// too, never swallowed. Nothing in memory has changed in any of these cases.
    static func writeFiles(templatesJSON: Data, historyJSON: Data?, settingsJSON: Data) throws {
        let steps: [(name: String, url: URL, data: Data?, encrypt: Bool)] = [
            ("templates.json", Storage.templatesURL, templatesJSON, true),
            ("history.json", Storage.historyURL, historyJSON, true),
            ("settings.json", Storage.settingsURL, settingsJSON, false),
        ]
        var previous: [Previous] = []
        for s in steps {
            do { previous.append(try readPrevious(s.url)) }
            catch { throw Failure.cannotReadPrevious(s.name, error) }
        }
        var done = 0
        do {
            for s in steps {
                if let data = s.data { try Storage.writeNow(data, to: s.url, encrypt: s.encrypt) }
                else { try Storage.removeNow(s.url) }
                done += 1
            }
        } catch {
            var undo: [(String, Error)] = []
            for i in 0..<done {
                do {
                    switch previous[i] {
                    case .bytes(let b): try Storage.writeRawNow(b, to: steps[i].url)
                    case .absent: try Storage.removeNow(steps[i].url)
                    }
                } catch let e { undo.append((steps[i].name, e)) }
            }
            if undo.isEmpty { throw Failure.writeFailed(steps[done].name, error) }
            throw Failure.undoFailed(steps[done].name, error, undo: undo)
        }
    }
}
