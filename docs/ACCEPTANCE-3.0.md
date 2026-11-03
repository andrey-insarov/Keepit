# Keepit 3.0 — manual acceptance

What the 122 unit tests cannot see: dialogs, the sandbox, real folders and disks, the process being
killed. Each case has steps and the one thing that must be true at the end. Tick as you go; anything
that does not match is a finding, not a note. Build under test: `release/3.0` at the commit named
when this run starts (CI artifact `Keepit-adhoc-<sha>` for the direct-download build; `make
appstore …` for the sandboxed one).

## Preparation (once, ~20 min)

- [ ] **P1. Two builds.** Ad-hoc DMG from Actions → latest `release/3.0` run → artifact
  `Keepit-adhoc-<sha>`; App Store build via `make appstore VERSION=$(cat VERSION) …` (RELEASING.md),
  installed from the `.pkg`. Do not run both at once except where a case says so.
- [ ] **P2. A clean macOS user** (System Settings → Users & Groups) for the baseline and the first-run
  cases. Everything else can run in your own account with a side instance:
  `KEEPIT_DATA_DIR=/tmp/keepit-acc /Applications/Keepit.app/Contents/MacOS/Keepit & echo $! > /tmp/keepit-acc.pid`
  — its data, vault and Touch ID keychain item are separate from the real installation's. Keep the
  PID file: the environment variable is not visible to `pgrep -f`, so `kill` by that PID.
- [ ] **P3. Folders:** one in iCloud Drive (`~/Library/Mobile Documents/com~apple~CloudDocs/KeepitTest`),
  one on an external disk or USB stick, one on a NAS share (SMB). An empty one for "another Mac".
- [ ] **P4. Seed data** in the instance under test: ~50 history items including an image and a file
  list, a few templates in two folders, one template with a hot key. Password protection ON, recovery
  phrase written down. One more set with protection OFF for the cases that need it.
- [ ] **P5. A 2.13.1 export** (`Keepit-backup-….keepit`, format 1) made by the released 2.13.1 — keep it
  for A2 and D7.
- [ ] Open `Console.app`, filter `subsystem:com.it.keep`, keep it visible: the engine and the restore
  log what they do; private values are redacted.

## A. Baseline — the 2.x path still works (stage 0)

- [ ] **A1. Sparkle.** On the clean user install 2.13.1 from the release page, let it find 3.0 when the
  tag exists (skip until then; do it before announcing), update in one click, data intact.
- [ ] **A2. Export → Reset → Import.** *Settings → General → Backup → Export…* with a file password
  → *Advanced → Reset…* (password and confirmation) → first-run dialogs → *Restore from Backup…* →
  that file → *Replace* (a fresh installation holds only the example templates: no rollback copy, no
  extra question). Expected: counts in the preview match what you exported; history, templates,
  template hot key back; preferences back only if *Also restore preferences* was on.
- [ ] **A3. Format 1 file (P5) opens** in 3.0 with its password; the file from A2 (format 2) does **not**
  open in 2.13.1 — it says the backup was made with a newer version, nothing worse.

## B. Switching automatic backup on

- [ ] **B1. No password → disabled.** Protection OFF: the checkbox is disabled, the status line says
  *Set a Keepit password (Security) to enable automatic backups.* and the ? explains it.
- [ ] **B2. On with a folder.** Protection ON: tick the checkbox → the folder chooser opens in iCloud
  Drive → pick the iCloud test folder → checkbox on, path shown, status *No backup yet.*
- [ ] **B3. Cancel the chooser** → checkbox goes back off, nothing saved.
- [ ] **B4. Keep last** accepts 1…100, rejects 0 and 101 (field clamps), unit label *backups*.
- [ ] **B5. Include this Mac's name** off by default; ? says the provider can see it.
- [ ] **B6. Back Up Now** → within a few seconds a file `Keepit-<UTC date>T<time>Z-<installation uuid>-<file uuid>.keepit`
  appears in the folder, no `.part` left behind, status *Last backup: <time> · <size>*. With B5 on,
  the Mac's name is in the file's header (run `head -c 400 <file> | strings` — the label is visible,
  nothing else of yours is).
- [ ] **B7. The settings window reflects the engine live:** leave it open, copy something, wait 5 min
  without touching Keepit → the status line changes by itself when the copy is written.

## C. Automatic behaviour

- [ ] **C1. Quiet period.** Copy three things within a minute → exactly one new file ~5 min after the
  last copy, not three.
- [ ] **C2. Nothing changed, no file.** *Back Up Now* always writes (it is forced). The fingerprint is
  for the automatic run, and copying anything — even the same text again — makes a new item (new
  id and date), so: rename a template folder, then rename it **back** within the quiet period → the
  content is what the last copy holds → no new file after five minutes.
- [ ] **C3. Rotation.** *Keep last* = 3, make 5 copies (change + Back Up Now) → exactly 3 of this
  instance's files remain, oldest gone. A file you put there yourself named `Keepit-foo.keepit`, and
  a copy from another instance (P2 side instance into the same folder), are **not** deleted.
- [ ] **C4. Two instances, one folder.** Real app and the side instance both backing up into the iCloud
  folder → two series with different installation uuids, each rotating only its own.
- [ ] **C5. Folder gone.** Eject the external disk (or rename the folder) → change something → *Back Up
  Now* → status *Last backup failed: Backup folder is not available*; put it back → next change or
  Back Up Now succeeds; status clears. Nothing crashed, no partial file.
- [ ] **C6. New folder = new series.** *Choose…* another folder → the old files stay where they were; the
  next copy is forced — it skips the "nothing changed" check, not the schedule: it comes after the
  quiet period (five minutes after the last change, or at once via *Back Up Now*) and goes to the
  new folder; rotation there does not count the old ones.
- [ ] **C7. Locked = nothing.** Lock (⌥L), change nothing, wait → no file; unlock → the pending copy, if
  any, is written.
- [ ] **C8. Password change / new phrase** → a fresh copy at the next run (forced, same timing as C6:
  after the quiet period or via *Back Up Now*); the old copies still open with the **old** password
  (D4), the new one with the new.
- [ ] **C9. Same file twice is impossible:** after C3 compare SHA-256 of two consecutive copies — they
  differ (random nonce, different backupID).

## D. Restore

Use *Settings → General → Backup → Restore…* unless stated. "Another Mac" = the clean user or the side
instance with an empty data directory.

- [ ] **D1. Own copy, same Mac, Merge.** Delete two history items and one template, Restore… the latest
  copy → opened **without** a password prompt (same vault) → preview counts → *Merge* → the deleted
  items are back, nothing duplicated, the backup's templates in a folder *Imported <date>* **without
  the hot key**; your own templates untouched. The next automatic copy is written and opens (this
  used to break).
- [ ] **D2. Own copy, Replace.** Change something, Restore… → *Replace* → a `Keepit-before-restore-…`
  file appears in the backup folder **before** the data changes, the progress panel *Saving a copy of
  your current data…* closes by itself, data equals the backup. Open the before-restore file with
  Restore… → it opens with the current password and holds what you had.
- [ ] **D3. Another Mac, password.** Copy the newest file to the "other Mac", Restore… → asked for *the
  Keepit password of the Mac this backup was made on* → wrong password twice: *Wrong password.*,
  third time: *Too many wrong attempts.* and the flow ends; again with the right one → preview →
  *Replace*. On a fresh installation without a password: after the restore, *Protect Keepit with the
  same password?* → *Use This Password* → protection on, no second prompt. Automatic backup is still
  off here (per-Mac setting): switch it on, choose the same folder → this Mac starts its **own**
  series next to the old Mac's; both keep rotating only their own.
- [ ] **D4. Another Mac, recovery phrase.** Same file, *Recovery Access…* in the password dialog → the
  24 words → opens. On a Mac **without** a password: Keepit asks to set one **before** anything is
  restored, then *Keep the recovery phrase?* → *Keep This Phrase* → afterwards the **old** phrase
  unlocks the new vault (lock → unlock with *Recovery Access…*). Repeat with *Make a New Phrase* → a
  new phrase is shown; the old one no longer works here. Cancel at the password → nothing restored,
  no vault created.
- [ ] **D5. Replace with protection off and existing data.** Side instance, protection OFF, some
  data; Restore… any file → *Replace* → asked for a password for the copy of the current data, then
  (no backup folder) for a folder → the before-restore file lands there → data replaced. Cancel the
  password or the folder → Replace does not happen, data untouched.
- [ ] **D6. Limits.** Set *History → keep* to 5, Restore… a backup with 50 items → *Not everything fits*
  names 5 / 45 → *Continue* → exactly 5 (the newest). Again with *Also restore preferences* and a
  backup whose limit was 1000 → all 50.
- [ ] **D7. Format 1 and a damaged file.** The P5 file restores with its password. Flip one byte in the
  middle of a copy (`printf '\x00' | dd of=f.keepit bs=1 seek=5000 conv=notrunc`) → *Wrong
  password.* / damaged, nothing changes. Rename a `.txt` to `.keepit` → *This is not a Keepit backup
  file.*
- [ ] **D8. Double-click in the Finder** with Keepit running → the same flow; while **locked** → asked for
  the Keepit password first, then the restore. Two files selected and opened together → two restores
  one after the other, never one inside the other.
- [ ] **D9. Trust never restored.** Backup made with keepit:// on and a trusted app, Touch ID on →
  restore with *Also restore preferences* on a Mac where these are off → they stay off, the backup
  folder setting stays this Mac's.

## E. First launch and cold launch

Clean user, fresh install each time (`rm -rf ~/Library/Application\ Support/Keepit` between runs for
the direct build; delete the container for the App Store one).

- [ ] **E1. Order.** First launch → *Restore from a backup?* comes first, then the password offer, then
  Accessibility. *Start Fresh* → password offer.
- [ ] **E2. Restore at first launch** → *Restore from Backup…* → a file from the iCloud folder → D3's
  password path → *Replace* — the store holds only the example templates, so no before-restore copy
  and no password or folder question → then *Protect Keepit with the same password?* Repeat after
  editing one example template before the restore → now Replace does ask (there is something to lose).
- [ ] **E3. Cold launch by file.** Keepit **not** running, double-click a `.keepit` → Keepit starts →
  (password gate if a vault exists) → the restore opens; on a first run it **replaces** the generic
  *Restore from a backup?* and comes before the password offer. **Replace** here must finish: the
  *Saving a copy…* panel closes on its own (this hung once).
- [ ] **E4. File during the welcome dialogs.** Start Keepit on a first run, and while *Restore from a
  backup?* is on screen double-click a `.keepit` → nothing opens on top; after the welcome dialogs are
  done the file's restore starts.

## F. Lock during a restore

- [ ] **F1.** Open Restore…, get to the preview, press ⌥L (or lock the screen with *Lock when the screen
  locks* on) → choose *Merge* → *Restore cancelled: Keepit was locked meanwhile.* → unlock → data as
  before.
- [ ] **F2.** Same, but lock while the **folder chooser** for the before-restore copy is open (protection
  off → on first, so a vault exists; or use the side instance) → choose a folder → cancelled, no crash,
  no copy written with a blank password (open the copy if one appeared: it must **not** open with an
  empty password).
- [ ] **F3.** Lock while the *Saving a copy…* panel is up (big history on the NAS folder, ⌥L) → the panel
  stays responsive, the restore is cancelled after the copy, data untouched.

## G. Crash safety — the restore journal

Side instance; watch `/tmp/keepit-acc/`.

- [ ] **G1. Kill between the writes.** Big history. Restore… → *Replace* → the instant *Saving a copy…*
  closes, `kill -9 $(cat /tmp/keepit-acc.pid)` (prepare the command; a few tries may be needed) →
  relaunch → data exactly as before the restore, `restore-journal/` gone, nothing in the log but
  *replayed an interrupted restore* if you caught the window.
- [ ] **G2. Replay that cannot finish.** With Keepit quit, in `/tmp/keepit-acc/`: build an armed journal
  that holds **every** existing file (a journal without a copy of a file means "that file did not
  exist" and the replay would delete it), then make the live history differ from its copy so the
  replay has to write it, and make that write impossible:
  ```
  mkdir restore-journal && cp history.json templates.json settings.json restore-journal/ && echo 1 > restore-journal/commit
  printf ' ' >> history.json && chflags uchg history.json
  ```
  → launch → an alert naming `history.json`, Keepit **quits**, `templates.json` and `settings.json`
  unchanged (compare mtimes), `restore-journal/commit` still there → `chflags nouchg history.json` →
  launch → replay succeeds (history back to the copy), Keepit runs, `restore-journal/` gone.
- [ ] **G3. Unarmed journal.** With Keepit quit and the live files **untouched** (no appended byte, no
  immutable flag — this is not G2's setup): `mkdir restore-journal && cp history.json restore-journal/`
  and **no** `commit` file → launch → no alert, `restore-journal/` removed, the three files' mtimes
  unchanged.

## H. App Store build — the sandbox

- [ ] **H1. Bookmark survives.** Choose a folder outside the container (iCloud Drive, then the external
  disk) → quit → relaunch → *Back Up Now* works without asking again (security-scoped bookmark).
- [ ] **H2. Stale bookmark.** Rename the folder → status *not available*; rename back → works again
  (bookmark refreshed, no re-prompt). Move the folder to another volume → *not available* until you
  *Choose…* again.
- [ ] **H3. Restore from a file** picked in the open panel, and by double-click from the Finder — both
  work (the file is user-selected; no "operation not permitted" in the log).
- [ ] **H4. Before-restore copy** goes into the bookmarked backup folder; with no folder configured the
  folder chooser appears and the copy lands where you chose.
- [ ] **H5. Container check:** nothing is written outside `~/Library/Containers/com.it.keep/` except
  the chosen folders. `backup.json` is in the container.
- [ ] **H6. No Sparkle:** no *Check for Updates…*, no *Updates* group in General, `otool -L` shows no
  Sparkle framework.

## I. NAS and slow volumes

- [ ] **I1. Normal.** Backup folder on the SMB share: copies land, rotation works, read-back is fine.
- [ ] **I2. Share disappears mid-write.** Start a big *Back Up Now*, pull the network → the app stays
  responsive, status *failed* with a readable reason, ⌥L works during the hang. A `.Keepit-….part`
  from the interrupted write may stay on the share: Keepit does not clean up a part file it did not
  finish (it has a different id from any later copy) — note it, delete it by hand; it must never be
  mistaken for a copy (Restore… does not list it as one).
- [ ] **I3. Hung share during Replace.** Same during the *Saving a copy…* panel → the panel stays live,
  ⌥L works. Keepit has no timeout of its own: the wait ends when macOS gives up on the share (SMB, a
  few minutes) — then the restore reports the error and is cancelled, data untouched. Note how long it
  took.
- [ ] **I4. Retry backoff.** After a failure, do nothing → the log shows retries at ~1, 5, 15, 60 min
  (watch at least the first two). A change in between does **not** shorten the wait — the next
  attempt is still at the scheduled retry; *Back Up Now* is the way to retry at once.

## J. Protection toggles, Reset, Uninstall

- [ ] **J1. Protection off** (Security) with automatic backup on → the checkbox in General goes off by
  itself, status *Automatic backup is off.*, no more copies. **Protection on again** → tick the
  checkbox → the previous folder is still shown and works without choosing again.
- [ ] **J2. Reset…** → `backup.json` removed, *Restore from a backup?* offered, then the password; after
  *Start Fresh*: add a template, quit, relaunch → the template is there (this was lost once).
- [ ] **J3. Reset → Restore → edit → relaunch** → the edit is there.
- [ ] **J4. Uninstall…** (direct build) removes the app, data and the keychain item; the backup folder
  and its files stay.

## K. Site and texts

- [ ] **K1.** keep.it.com/guide: First launch (3 steps), Settings table General row, Backup section,
  the two new troubleshooting entries; the intro link to `/v2/guide.html` works and the frozen page
  shows the banner with a link back; `/v2/` pages are `noindex` (view source) and absent from
  `/sitemap.xml`.
- [ ] **K2.** security.html *Backups*, privacy.html *Backups you choose to make* (version 1.4), landing
  card *Backed up to your own cloud* and the FAQ answer — read once as a user, not as the author.
- [ ] **K3.** New screenshots to take for the guide: General pane with the Backup group (on, a folder
  chosen, a status line), the restore preview, the first-run *Restore from a backup?* dialog. White
  background, window shadow, RGB PNG into `docs/site/img/guide/`.

## Sign-off

- [ ] Every box above ticked or turned into a finding on PR #6.
- [ ] Auditor's look at the stage-5 texts done.
- [ ] Then: merge PR #6, `cat VERSION` → `3.0.0`, tag `v3.0.0`, approve the release run, verify the
  release page, the cask bump and the landing's version; A1 on the clean user; submit the App Store
  build.
