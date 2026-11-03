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
    enum Failure: LocalizedError, Equatable {
        case locked
        var errorDescription: String? {
            switch self {
            case .locked: return L("Restore cancelled: Keepit was locked meanwhile.")
            }
        }
    }

    /// Write templates, history (nil → the file is removed: history is not kept on disk) and
    /// settings. If any write fails, the files written so far are put back to their previous bytes
    /// and the error is rethrown — nothing in memory has changed yet, so the app is where it was.
    static func writeFiles(templatesJSON: Data, historyJSON: Data?, settingsJSON: Data) throws {
        let steps: [(url: URL, data: Data?, encrypt: Bool)] = [
            (Storage.templatesURL, templatesJSON, true),
            (Storage.historyURL, historyJSON, true),
            (Storage.settingsURL, settingsJSON, false),
        ]
        let previous = steps.map { try? Data(contentsOf: $0.url) }      // raw bytes as they are on disk
        var done = 0
        do {
            for s in steps {
                if let data = s.data { try Storage.writeNow(data, to: s.url, encrypt: s.encrypt) }
                else { try Storage.removeNow(s.url) }
                done += 1
            }
        } catch {
            for i in 0..<done {
                if let bytes = previous[i] { try? Storage.writeRawNow(bytes, to: steps[i].url) }
                else { try? Storage.removeNow(steps[i].url) }
            }
            throw error
        }
    }
}
