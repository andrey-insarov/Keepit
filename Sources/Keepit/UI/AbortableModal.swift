import AppKit

/// A modal dialog that a lock may close. `lock()` aborts the running modal session only while the
/// *current* session is one of these; every other `runModal` (the recovery phrase, which must be
/// read before it goes; a password prompt; the restore progress panel with its own completion
/// rules; a panel over one of ours) is left alone — ownership is by window, not by a count
/// (auditor's P2 on PR #28). A dialog opened here returns `.abort` when the lock closed it;
/// callers treat that as Cancel — and, where the dialog's result would have acted on data read
/// before it opened, check the lock generation as well (`lockCount`), because a lock followed by
/// an unlock also ends here. A wrapped dialog opened over another wrapped dialog unwinds both: when
/// the inner one returns into the outer one's loop, the request is applied again.
enum AbortableModal {
    private(set) static var windows: [NSWindow] = []
    private static var abortRequested = false

    static var depth: Int { windows.count }
    static var isRunning: Bool { !windows.isEmpty }

    @discardableResult
    static func run(_ alert: NSAlert) -> NSApplication.ModalResponse {
        windows.append(alert.window)
        let response = alert.runModal()
        windows.removeLast()
        if abortRequested {
            // Back in the parent's loop. A wrapped parent that is the session now goes too; an
            // ordinary one (a password prompt under a template prompt, say) stays, and the request ends.
            if let parent = windows.last, NSApp.modalWindow === parent { NSApp.abortModal() } else { abortRequested = false }
        }
        return response
    }

    /// What `lock()` calls: ends the current modal session if it belongs to an abortable dialog.
    static func abortIfRunning() {
        guard let top = windows.last, NSApp.modalWindow === top else { return }
        abortRequested = true
        NSApp.abortModal()
    }
}
