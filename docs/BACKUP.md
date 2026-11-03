# Automatic encrypted backup — design and acceptance criteria (3.0)

Status: agreed design, 3 Nov 2026. The file format is in [FORMAT.md](FORMAT.md). This document is
what the implementation is checked against; change the document first, then the code.

## What it is, and what it is not

Keepit writes encrypted copies of the history and templates into a folder the user chose — usually
one that a cloud service syncs (iCloud Drive, Dropbox, a NAS). The user can later restore from any of
those copies, on this Mac or another, with the Keepit password or the recovery phrase.

It is a **backup**, not synchronisation. Two Macs writing into the same folder produce two
independent series of files; neither reads the other's automatically. There is no merge on launch:
a deleted secret must stay deleted, and that is impossible to promise once two live histories are
merged without the user looking. Merge exists only as an explicit, one-time choice inside *Restore*.

## Preconditions

- **Password protection must be on.** The backup key is derived from the vault's data key; without a
  vault there is no key, no salt and no recovery block. In Settings the option is disabled with
  "Set a Keepit password to enable automatic backups" and a button that goes to Security. Turning
  protection off turns automatic backup off; existing files stay where they are.
- **Changing the password or the recovery phrase does not change existing copies.** They keep
  opening with the password (or phrase) that was current when they were written. The password-change
  and new-phrase dialogs say so in one line, and the security page does too. A change of password
  or phrase forces a fresh backup (see triggers), so the newest copy always opens with the current
  credentials.

## Key and file

- Mode `auto` of container v2 (FORMAT.md): header carries the vault's `kdf`, `rounds`, `salt` and,
  if present, the recovery block; file key = HKDF(data key, info `keepit-backup-v2`); fresh nonce
  per file; header bytes are the GCM additional data.
- The file is opened with the vault password of the writing installation, or with its recovery
  phrase. A matching salt lets Keepit try the key already in memory without asking; the GCM tag is
  the only proof the key is right.
- Name: `Keepit-<yyyyMMdd>T<HHmmss>Z-<sourceID>-<backupID>.keepit`. `sourceID` is a random UUID
  created when automatic backup is first enabled (reset by *Reset…*); `backupID` is random per file.
  Neither is derived from hardware, the user or the Mac's name.
- Optional **device label** (off by default) in the header, for telling series apart in the Restore
  list. It is plaintext metadata in the cloud; the setting says so.
- Nothing in the header reveals content: no counts, no hashes. Identical content yields different
  files.

## When a backup is made

Two independent timers, both persisted in `settings.json` so they survive a relaunch:

- **Quiet period**: 5 minutes after the last change to history or templates.
- **Deadline**: at most 24 hours after the *first* unsaved change, however busy the clipboard is.

Checked on: change (debounced), launch, unlock, wake from sleep, timer. *Back Up Now* ignores both.

A backup is skipped when:

- Keepit is **locked** (no key in memory). Changes made before the lock may not be in a backup yet;
  they are in the local store and are written at the next unlock — the dirty state is not cleared.
- the **fingerprint** of the snapshot equals the one of the last successful backup. The fingerprint
  is computed locally over a stable snapshot (history, templates, the restorable part of settings) —
  never over timestamps, backup status or other bookkeeping — and is stored locally only.

A backup is **forced** regardless of the fingerprint when any of these changed since the last
successful one: the password or KDF parameters, the recovery phrase (created or replaced), the
container format, the destination folder. Otherwise a new phrase might never reach any file.

A failed attempt leaves the dirty state in place and retries with increasing delay (1, 5, 15, 60
minutes, then hourly). The status line shows the last error.

## How a backup is written

Three stages on three queues, so that a slow or hung destination can never hold the vault open or
block ordinary saving:

1. **Snapshot** (main thread, immediate): history array, encoded template tree, restorable settings,
   current KDF parameters and recovery block, fingerprint. One consistent state; the key, the
   recovery block and the data in a file always belong to the same moment.
2. **Seal** (`Storage.ioQueue`): compress, encrypt with the HKDF key, then **verify the container
   while the key is still available**: parse the header back, open the GCM box, compare the
   plaintext hash with the snapshot's. Compute `SHA-256` of the complete file bytes and keep it in
   the job. This is the only stage that needs the data key, and it is short.
3. **Write** (`backupQueue`, separate): resolve the bookmark (start/stop security scope paired, in
   `defer`), write to a temporary file in the destination folder (`.Keepit-….keepit.part`), `fsync`,
   **read it back and compare its SHA-256 with the job's** — a byte-exact check that needs no key;
   only then rename atomically to the final name; record `(sourceID, backupID, name, size, date,
   sha256)` in the local registry; update *Last backup*.

Lock and key changes wait for stage 2, never for stage 3. If the key is wiped during stage 3,
nothing happens: the bytes are already ciphertext and already verified.

Atomicity and durability on network volumes depend on the file system and protocol. The security
page says so and recommends a local or iCloud/Dropbox folder; a NAS is "verify your setup".

## Rotation

- Keep the last **N** (default 10) files of **this installation's series** — identified by the
  local registry of successful writes, not by parsing names or headers of whatever is in the
  folder.
- Old files are deleted **only after** a new one has been written and verified.
- Files Keepit did not write (another Mac's series, manual exports, anything it cannot verify as
  its own) are never deleted and never counted.
- The copy made before a *Replace* restore (`Keepit-before-restore-….keepit`) is outside rotation.

## Destination folder

- Chosen with `NSOpenPanel`, stored as a **security-scoped bookmark** (app-scope; the App Store
  build gets the `com.apple.security.files.bookmarks.app-scope` entitlement). The same code path in
  both editions.
- A stale bookmark is refreshed while access still works; if it cannot be, the status asks for
  *Choose…* and backups pause (dirty state kept).
- A bookmark is not portable: it means nothing on another Mac or after a Reset.
- An unavailable folder must not block local saving or *Lock*; it only fails stage 3.

## Restore

Entry points: first launch and after *Reset…* (*Restore from Backup… / Start Fresh*); *Settings →
General → Backup → Restore…*; double-click on a `.keepit` file. All lead to the same flow:

1. **Pick**: the user chooses a file (or a folder, from which Keepit lists files it can parse). The
   sandbox grants access only through this choice; Keepit does not scan iCloud Drive on its own.
   Before anything is unlocked the list shows only date, size and the optional label, marked as
   unverified.
2. **Unlock**: read the whole file, enforce header limits, range-check `rounds`, then ask for the
   password — or, if the header has a recovery block, offer *Recovery Access…* with the 24 words.
   If the current vault is open and the salt matches, try the current key first, silently.
3. **Verify**: GCM tag (the only proof), then decompress with a running limit of 512 MiB, then
   decode and validate the payload against `Limits` as untrusted input. Nothing has changed yet.
4. **Preview**: counts, date, device label (now trusted), what will happen.
5. **Choose**: **Replace** or **Merge**.
   - *Replace* first secures the current data, then replaces it. Three cases:
     - **Nothing to lose** (history and templates empty — a fresh installation, or right after
       *Reset…*): no rollback copy; Replace proceeds.
     - **Existing data, vault on**: a mandatory rollback copy (`Keepit-before-restore-…`, mode
       `auto`, current key) is written and verified like a regular backup — into the backup folder
       if one is configured, otherwise into a folder the user picks now (choosing a *file* in
       `NSOpenPanel` grants no right to write next to it, so Keepit asks for a folder explicitly).
       If the copy cannot be written, Replace does not start.
     - **Existing data, vault off**: the rollback copy is a manual-mode export; the user is asked
       for a password for it (same dialog as *Export…*) and for a folder. Declining either cancels
       Replace. Turning protection on first is offered as the simpler route.
   - *Merge* adds history items whose `contentHash` is not present, keeping the current items
     newest. Added items get fresh ids: the backup may be this Mac's own, and an item edited here
     since would otherwise return under an id already in use — which the next backup's validator
     rejects. The backup's template tree is added whole as a new top-level folder named
     "Imported <date>" (the rule *Import…* has used since 2.x), deep-copied with fresh ids and
     **without hot keys** (a copy never inherits a key, as with drag-copy), so the user sees exactly
     what came from the backup and can move or delete it. Nothing is overwritten and nothing is
     matched by `id` — two Macs editing "the same" template are two templates.
   - The rollback copy is produced like a regular backup — sealed on `Storage.ioQueue`, written,
     fsynced and read back on a background queue, the main thread waiting in a small progress
     panel — but it is captured only in the commit stage (below), after the last dialog: the
     snapshot (history, the template tree as bytes, settings) and the key are taken and handed to
     `ioQueue` in one synchronous step, and Lock drains that queue before zeroing the key, so the
     seal never meets a zeroed key. Replace proceeds only after the read-back matched.
6. **Plan, then commit** (`RestorePlan`, `RestoreCommit`). Everything that needs the user is asked
   first — the limits check, the rollback copy's password and folder, a new password when the
   phrase opened the file — and nothing is captured or changed while those dialogs are open.
   Then the commit stage runs with no more questions:
   - The clipboard watcher is paused, so the stores stand still; their revisions
     (`HistoryStore.revision`, `TemplateStore.revision`, `settingsRevision`, `lockCount`) are the proof.
   - The plan is computed as the complete next state: the final settings first (when preferences
     are restored, the backup's — minus the local keys below — clamped), the history trimmed by
     *those* settings (restoring 3 items together with `historyMax = 3` keeps 3, whatever the
     limit was before), the template tree composed on a clone of the current one and checked
     against the count and depth ceilings. A plan that does not fit fails as a whole; items the
     final limits would drop were reported before the user confirmed.
   - For Replace, the rollback copy is written of exactly the state the plan was made from. If the
     revisions moved while it was being written (a paste from the menu, say), the plan is made
     again and the copy taken again, up to three times; after that the restore is cancelled with a
     message rather than replacing something the copy does not hold.
   - Commit: templates, history and settings are written to disk as one step
     (`RestoreCommit.writeFiles`, throwing). Before the first write every existing file is read in
     full — a file that is there but cannot be read cancels the commit untouched (it is not treated
     as absent). If a write fails, the files written so far are put back to their previous bytes
     (or removed, when there was none) and the error names the file; if that undo fails too, the
     error says so and which files, never silently. Nothing in memory has moved in any of these
     cases. Only when all three are on disk are the live stores assigned, then hot keys, menus and
     the Viewer refreshed, then "Restore finished".
     Known limit: this is undo-on-error, not crash-atomic — a process killed between the three
     writes leaves the files mixed. A journal (copies of the three files plus a marker, replayed at
     the next launch) would close that; it is a 3.x item, not in 3.0.
   - A lock at any point before the commit cancels the restore with a message: the stores were
     purged and reloaded and the plan is stale.
7. **Settings** come back selectively. Never restored: `allowURLCommands`, `trustedURLSenders`,
   `biometricUnlock`, `biometricPasswordChange`, the backup folder bookmark, anything with a local
   path. The user is told what was skipped.
8. On a **fresh installation** restored with a password, offer to keep that password as this
   installation's vault password (so automatic backup into the same folder continues without
   setup) or to set a new one. Opened with the **recovery phrase** on a Mac without a password: a
   new password is required *before* the plan is applied — the vault is created first, so the
   restored data never lands unencrypted; cancelling leaves the current data unchanged. The user
   chooses whether the phrase from the backup keeps working for the new vault (it is wrapped for
   the new key under a new salt) or a new phrase is generated and shown.

## Settings UI (General → Backup)

- ☐ **Back up automatically to a folder** — disabled without a password (see Preconditions).
- Folder path + *Choose…*
- **Keep last** [10] **backups**
- ☐ **Include device label** [MacBook Pro] — off by default; help says it is visible to the storage provider.
- Status line: *Last backup: today 10:12 · 1.2 MB* / *Last backup failed: folder not available*
- *Back Up Now* · *Restore…*
- Export… / Import… stay as they are (manual mode, own password).

## Acceptance criteria

Automatic tests (temporary folders, fakes where macOS is involved):

- [ ] A change → quiet period → one file; a burst of changes → one file.
- [ ] Continuous changes for longer than the deadline → a file by the deadline.
- [ ] Locked → no attempt; unlock → the pending backup runs.
- [ ] Unchanged fingerprint → no file; password change, new phrase, new folder → a file each.
- [ ] Write fails (disk full / permission) → no partial file left, old files intact, dirty kept, status shows the error, retry scheduled.
- [ ] Folder missing → same as above, status asks to choose; local saving and Lock unaffected (Lock completes while a fake destination is hung).
- [ ] Interrupted write → `.part` file is ignored by rotation and overwritten next time.
- [ ] Read-back verification fails (fake corruption on write) → file discarded, nothing rotated.
- [ ] Rotation keeps N of own series; another series and foreign files in the folder are untouched; N = 1 still leaves the before-restore copy.
- [ ] Registry out of sync (file deleted by hand) → no error, no deletion of anything else.
- [ ] Restore: password opens; recovery phrase opens (no local vault.json involved); wrong password → clean error; tampered header → authentication failure; `minReader` above ours → "needs newer Keepit"; `rounds` out of range → rejected before PBKDF2; oversized payload → rejected during decompression.
- [ ] Restore Replace: empty store → no rollback copy, proceeds; data + vault → rollback copy written and verified first; data, no vault → export password and folder asked, declining cancels; rollback copy cannot be written → refused, data untouched.
- [ ] Restore Merge: duplicate hashes skipped; added items and the "Imported <date>" folder carry fresh ids and no hot keys; merging this Mac's own backup leaves the next backup valid; over the template count or depth limit → refused, nothing changed (`RestorePlanTests`).
- [ ] Restore plan: history trimmed by the restored settings, not the previous ones; items that do not fit are reported before confirmation; trust and backup setup never restored (`RestorePlanTests`).
- [ ] Restore opened with the phrase, vault off: password asked and vault created before anything is applied; cancel → data unchanged; "Keep This Phrase" → the backup's phrase unlocks the new vault.
- [ ] Lock during any restore dialog → restore cancelled, stores untouched; rollback copy written off the main thread (progress panel stays responsive); Lock while the folder chooser is open, then choosing a folder → cancelled, no crash.
- [ ] Data changing during the commit stage (paste from the menu while the rollback copy is being written) → the copy is taken again; the restored state is what the last copy holds; nothing recorded during the dialogs is lost on Merge.
- [ ] Disk write failing during commit (history.json unwritable) → error names the file, previous files intact, stores unchanged; an existing but unreadable file → commit refused before any write (`RestorePlanTests.testCommitWritesAllFilesOrPutsThePreviousOnesBack`).
- [ ] Trust settings never restored.
- [ ] Every fixture in `Tests/KeepitTests/Fixtures` (v1 and v2) opens as its sidecar says.

Manual, before release (Andrey):

- [ ] iCloud Drive folder, Dropbox folder, external disk, SMB share: enable, see the file appear, pull the disk / disconnect the share mid-run, see the status, reconnect, see it recover.
- [ ] Fresh user account on the same Mac: Restore from Backup with the password; again with the phrase; again with a manual export (v1 from 2.13) — compare text, RTF, image, file list, template tree, settings.
- [ ] App Store build: the folder picker works, access survives a relaunch, revoked access is reported.

## Out of scope for 3.0

Sync between Macs; restoring individual items from a backup; backups of a locked vault; scheduled
backups while Keepit is not running.
