import Foundation

/// Everything a restore will change, computed and checked *before* any store is touched —
/// docs/BACKUP.md "Apply as one transaction". Pure: no AppKit, no disk, no store mutation, so the
/// rules are unit-tested directly and `apply` in the app is a handful of assignments.
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
///   and without hot keys (a copy of a template never inherits its key, same as drag-copy). The
///   folder is checked against the count and depth ceilings here; if it does not fit, nothing fits.
/// - Replace takes the backup's history and template tree as they are (ids, hot keys), trimmed by
///   the final settings. The payload was validated when it was opened.
struct RestorePlan {
    enum Mode { case merge, replace }

    enum Templates {
        case replace(TemplateNode)
        case addFolder(TemplateNode)
    }

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
    let templates: Templates
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
        let templates: Templates
        let templatesAdded: Int
        switch mode {
        case .replace:
            candidate = payload.history
            fresh = candidate.count
            templates = .replace(payload.templates)
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
            // The folder sits at depth 1 under the root; the validator's rule is "deepest node ≤ max".
            guard currentTemplates.subtreeCount + folder.subtreeCount <= Limits.templateMaxCount,
                  1 + Self.height(of: folder) <= Limits.templateMaxDepth else { throw Failure.templateLimit }
            templates = .addFolder(folder)
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
