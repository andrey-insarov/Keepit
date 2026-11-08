import AppKit

/// A modal dialog that a lock may close. `lock()` aborts the running modal session only while the
/// *current* session is one of these; every other `runModal` (the recovery phrase, which must be
/// read before it goes; a password prompt; the restore progress panel with its own completion
/// rules; a panel over one of ours) is left alone — ownership is by window, not by a count
/// (auditor's P2 on PR #28). A dialog opened here returns `.abort` when the lock closed it;
/// callers treat that as Cancel — and, where the dialog's result would have acted on data read
/// before it opened, check the lock generation as well (`lockCount`), because a lock followed by
/// an unlock also ends here. A wrapped dialog opened over another wrapped dialog unwinds both: when
/// the inner one returns into the outer one's loop, the request is applied again. A system panel
/// that one of ours opens *and that shows the same content* — the print panel over the recovery
/// phrase — is run through `runForeign`, and a lock ends it and then the dialog under it.
enum AbortableModal {
    private(set) static var windows: [NSWindow] = []
    private static var abortRequested = false
    private static var foreignDepth = 0

    static var depth: Int { windows.count }
    static var isRunning: Bool { !windows.isEmpty }

    /// Tests only: answers the alert (by its message) instead of running it. The closure may lock
    /// the app first, as a lock during the dialog would.
    static var responseForTesting: ((String) -> NSApplication.ModalResponse)?

    @discardableResult
    static func run(_ alert: NSAlert) -> NSApplication.ModalResponse {
        if let test = responseForTesting { return test(alert.messageText) }
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

    /// A system panel with its own app-modal session, opened from an abortable dialog and showing
    /// what the dialog shows (`NSPrintOperation.run()` from the recovery-phrase sheet: the panel's
    /// preview is the phrase). While it runs, `NSApp.modalWindow` is the panel, so the plain rule
    /// above would leave both it and the sheet behind it on screen (3.0.6 audit, SEC05 round 1:
    /// Show… → Print… → lock → Cancel left the phrase open). A lock during `body` ends the
    /// panel's session; when control is back in the dialog's loop, the request ends the dialog.
    static func runForeign(_ body: () -> Void) {
        foreignDepth += 1
        body()
        foreignDepth -= 1
        if abortRequested, let top = windows.last, NSApp.modalWindow === top { NSApp.abortModal() }
    }

    /// What `lock()` calls: ends the current modal session if it belongs to an abortable dialog —
    /// or to a foreign panel such a dialog opened through `runForeign`. Any other session (a
    /// password prompt over a template prompt, say) is left alone, and the request with it.
    static func abortIfRunning() {
        guard let top = windows.last else { return }
        guard NSApp.modalWindow === top || foreignDepth > 0 else { return }
        abortRequested = true
        if NSApp.modalWindow != nil { NSApp.abortModal() }   // a foreign step between two sessions: the request waits in runForeign
    }
}
