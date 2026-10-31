# Keepit – Clipboard Manager

**Keepit – Clipboard Manager** (https://keep.it.com) is a native macOS clipboard history / template manager — a fork and
port of [CLCL](https://github.com/nakkag/CLCL) by Ohno Tomoaki (nakka), the Windows original.
History, hot-key popup menu, auto-paste, hierarchical templates, an Explorer-like Viewer with
per-format editing, and optional password protection with encrypted storage.

Keepit is not affiliated with or endorsed by the author of CLCL. The CLCL name and icons belong to
him; Keepit reuses only the behaviour and settings model, under the MIT License (see `LICENSE`).

Written in Swift + AppKit, no Xcode project needed — builds with `swift build`.

## Features (what is ported)

| CLCL (Windows)                               | Keepit (macOS)                                            |
|----------------------------------------------|------------------------------------------------------------|
| Tray icon, left click = menu, right = viewer | Menu-bar icon 📎, left click = history menu, right click = Viewer |
| `Alt+C` history+template popup, pastes       | `⌥C` (configurable), pops at the text cursor, pastes with `⌘V` |
| `Alt+T` template popup                       | `⌥T` (configurable)                                        |
| Numbered menu items `&1 … &9 &0 &A …`        | Same: press `1-9`, `0`, `A-Z` while the menu is open       |
| Bitmap thumbnails and tooltips in the menu   | Same (PNG thumbnails, text tooltips)                       |
| Formats: TEXT, UNICODE, RTF, HTML, BITMAP, HDROP | plain text, RTF, HTML, PNG (TIFF converted), file URLs |
| History max (30), overlap check, save/restore| Same, JSON in `~/Library/Application Support/CLCL/`        |
| Window filter (ignore apps)                  | Built-in list of password managers (always ignored) + user ignore list + `org.nspasteboard.ConcealedType` |
| Per-window paste key (`sendkey`)             | Per-bundle-id paste key in `settings.json` (`pasteKeys`)   |
| Templates (hierarchical "Regist")            | Same: folders, any format (text/image/files), `-` separators, `&x` shortcuts, per-item hot key |
| Viewer: tree Clipboard / History / Template  | Same tree; each item expands into its formats              |
| Viewer: edit text, bitmap view, file list, binary view | Text/RTF/HTML editing (applied when focus leaves), image view, file list (double-click opens), hex dump toggle |
| Viewer context menu                          | Send to Clipboard, Paste, Add to Template, New Item/Folder, New Item from File, Rename, Clear Name, Set Hot Key, Save Format to File, Up/Down, Delete |
| Viewer drag & drop                           | History → Template (copy), Template → History (copy), reorder within each |
| Status bar                                   | Date, source app, format, size, hot key                    |
| Options dialog (CLCLSet)                     | Preferences window with hot-key recorder                   |

Still not ported: plugins/tools, format filter/priority option pages, importing Windows
`history.dat` / `regist.dat`, the `%0d`-style menu numbering format.

## Build

Requirements: macOS 13+, Xcode Command Line Tools (`xcode-select --install`).

```bash
make app        # → Keepit.app in the project folder
make run        # build and launch
make install    # copy to /Applications
make dmg        # → Keepit-<version>.dmg (drag-and-drop installer with Applications shortcut)
make dist       # → both the .dmg and a .zip, as attached to GitHub Releases
make notarize SIGN_ID="Developer ID Application: …" NOTARY_PROFILE=…   # signed + notarized (see RELEASING.md)
```

Or in Xcode: `open Package.swift` and run the `Keepit` scheme (the `LSUIElement` key in
`Resources/Info.plist` is only applied by the `make app` bundle; from Xcode you'll also see a Dock icon). Bundle id: `com.it.keep`.

## First launch

1. macOS will ask for the **Accessibility** permission (System Settings → Privacy & Security →
   Accessibility). It is required to send `⌘V` to the active app and to place the menu at the
   text cursor. Without it Keepit still records history and copies the chosen item to the clipboard.
2. Press `⌥C` in any text field — the history menu appears; pick an item, it is pasted.
3. Press `⌥T` for templates. Right-click the menu-bar icon (or `⌘L` in any Keepit window) to open the Viewer.

## Viewer

* Left: tree. **Clipboard** is the live pasteboard (read-only). **History** and **Template** items
  expand into their formats (TEXT, RTF, HTML, PNG, FILE LIST).
* Right: the selected format. Text, RTF and HTML are editable; the edit is applied when the editor
  loses focus (as in CLCL). Editing TEXT drops stale RTF/HTML from that item. **Binary** toggles a hex dump.
* `↩` sends the selected item (or single format) to the clipboard; `⌫` deletes it. Right-click for
  the full menu. Drag history items onto the Template tree to register them.
* Template names: `-` makes a separator in the popup menu, `&G` makes `G` the shortcut, `&&` is a
  literal ampersand; an empty name shows the item's contents instead (*Clear Name*).
* *Set Hot Key…* on a template item pastes it directly, without a menu.

### Accessibility permission resets after rebuild

If you have a Developer ID certificate, build local test copies with the same identity as the
release and the permission survives every rebuild:

```bash
make install SIGN_ID="Developer ID Application: Your Company (TEAMID)"
```


`make app` signs the bundle ad-hoc (`SIGN_ID=-`). macOS ties the Accessibility grant to the code
signature, so after each rebuild you may need to toggle Keepit off/on in the Accessibility list.
To avoid that, create a self-signed "Code Signing" certificate in Keychain Access (e.g. named
`Keepit Dev`) and build with:

```bash
make app SIGN_ID="Keepit Dev"
```

## Password protection (2.0)

Preferences → *Require password at launch, encrypt history & templates*. You set a password once;
from then on Keepit asks for it at every launch (three wrong attempts → quit) and nothing is loaded
until it is entered. `history.json` and `templates.json` are then stored as AES-256-GCM blobs
(key = PBKDF2-HMAC-SHA256, 200 000 rounds, random 16-byte salt kept in `vault.json` together
with a sealed verifier). The password itself is never written anywhere and there is no recovery.
`settings.json` stays in plain text (it holds no clipboard data). *Change Password…* re-encrypts;
unticking the option asks for the password and writes the files back as plain JSON.

### Touch ID

Preferences → *Unlock with Touch ID*. The data key is stored in the data-protection keychain behind
a `biometryCurrentSet` access control (Secure Enclave backed; invalidated if fingerprints change),
so at launch or after *Lock* a fingerprint fetches the same key the password would derive — the
password is always available as a fallback ("Use Password" on the prompt). Changing the password
refreshes the entry; turning protection off removes it. Requires a Team-ID-signed build (release
or `make install SIGN_ID=…`); ad-hoc builds say so and keep using the password.

### Recovery phrase

Turning protection on shows a 24-word recovery phrase (standard BIP-39 English list with
checksum). A key derived from the phrase (HKDF) wraps the data key inside `vault.json`; the phrase
itself is never stored. Print it (the dialog offers the system print panel, which can also save a
PDF) and keep it offline — anyone holding it can read the history. If you forget the password,
the unlock prompt's *Use Recovery Phrase…* unlocks the data and immediately asks for a new
password. The phrase keeps working after password changes; *New Recovery Phrase…* in Preferences
replaces it (the old sheet becomes useless). Lose both password and phrase and the data is
unrecoverable — by design.

### Key handling and locking

* The derived key lives in a dedicated `mlock`ed buffer (never swapped) and is wiped with
  `memset_s` when Keepit locks, when the password is changed/removed, and at quit. A CryptoKit
  `SymmetricKey` is created only for the duration of one encrypt/decrypt call and its temporary
  copy is wiped afterwards. Password bytes and the PBKDF2 output buffer are wiped right after
  key derivation.
* The password dialog uses a custom field (`SecurePasswordField`): every key press is converted to
  UTF-8 and appended straight into an `mlock`ed `SecureBuffer`; only bullets are drawn. No `String`
  holding the password is ever built, paste/copy are disabled, backspace wipes the removed bytes,
  the "repeat password" check is a constant-time byte compare, and the buffer is wiped as soon as
  the key is derived. Limitation: input methods / dead-key composition are not supported — type
  the password with a plain keyboard layout. (What remains outside our control is the one-character
  `NSEvent.characters` string macOS creates per key press.)
* **Lock Keepit** (menu-bar icon → *Lock Keepit*, `⌘L`): wipes the key, unloads history and templates
  from memory, stops watching the clipboard and unregisters hot keys. The icon turns into a lock;
  click it → *Unlock Keepit…* to enter the password and resume. Pending edits are saved (encrypted)
  before the key is wiped.
* *Lock Keepit when the screen locks or the Mac sleeps* (Preferences, on by default) does the same
  automatically on screen lock, fast user switch and sleep.
* While locked, nothing is decrypted and the hot keys do nothing. What is on the system
  clipboard itself is of course still readable by every app — that is outside Keepit's control.

## Testing

* `swift test` — unit tests (models, menu parsing, settings, history/template stores, vault
  encryption and key zeroization). Runs on every push in GitHub Actions.
* `Keepit --selftest` — end-to-end smoke test inside the real app: captures a clipboard change,
  checks dedupe, inserts a template, builds the menus, opens the Viewer and Preferences and saves
  PNG snapshots of them to `selftest-output/`, round-trips the vault. Set `KEEPIT_DATA_DIR` to a
  temporary folder so your real data is untouched. CI runs it on every build and uploads the
  snapshots as an artifact (Actions → run → *selftest-…*), so UI regressions can be eyeballed.
* Hot keys, synthetic ⌘V and the caret lookup need the Accessibility permission and a real user
  session, so they can't run on a CI runner — test those by hand (or let Claude do it on a
  linked Mac) before tagging a release.

## Icon

`Resources/Icon/icon.svg` is the source; `make icon` re-renders `AppIcon.icns` (all sizes, PNG-packed)
with the Playwright/Chromium script, or on a Mac render the PNGs any way you like and run
`iconutil -c icns AppIcon.iconset`. The `.icns` is committed so the CI build doesn't need a renderer.

## Files

```
~/Library/Application Support/Keepit/
  settings.json    options (editable by hand; missing keys fall back to defaults)
  history.json     clipboard history (base64 data per format)
  templates.json   template tree
  vault.json       salt + verifier, only when password protection is on
```

Example `pasteKeys` override in `settings.json` (an app that pastes with ⇧⌘V):

```json
"pasteKeys": {
  "com.example.someterminal": { "keyCode": 9, "command": true, "shift": true, "option": false, "control": false }
}
```

## Architecture (where the Windows code went)

```
Sources/Keepit/
  main.swift                   WinMain → NSApplication
  AppDelegate.swift            main.c: tray icon, hot-key dispatch, popup menus, actions
  Models/
    ClipItem.swift             Data.c / Format.c / fmt_*.c: one history entry with its formats
    TemplateNode.swift         Regist.c tree node
    Settings.swift             Ini.c option struct (JSON instead of ini)
  Core/
    ClipboardMonitor.swift     ClipBoard.c: WM_CLIPBOARDUPDATE → NSPasteboard.changeCount polling
    HistoryStore.swift         History.c
    TemplateStore.swift        Regist.c persistence
    HotKeyManager.swift        RegisterHotKey → Carbon RegisterEventHotKey
    Paster.swift               SendKey.c (keybd_event) → CGEvent; caret lookup via Accessibility API
    Storage.swift              File.c / Profile.c: JSON files in Application Support
    Vault.swift                password prompt, PBKDF2 → AES-GCM for the data files
  UI/
    MenuBuilder.swift          Menu.c: owner-drawn menu → NSMenu with images, key equivalents, tooltips
    HotKeyRecorderView.swift   SetHotkey.c
    PreferencesWindow.swift    CLCLSet (subset)
    ViewerWindow.swift         Viewer.c / TreeView.c / ListView.c: tree + actions + drag & drop
    FormatViews.swift          fmt_text_view.c / fmt_bitmap_view.c / fmt_file_view.c / BinView.c
```

## Platform notes

* **Clipboard listener**: macOS has no change notification; polling `changeCount` every 0.3 s
  costs essentially nothing (it is an integer read).
* **Low-level keyboard hook** (`WH_KEYBOARD_LL`) is not needed: Carbon hot keys deliver the
  event only to us, and `NSMenu` handles the digit/letter accelerators natively.
* **Focus**: an `NSMenu` needs our process to be active to receive keyboard input, so we activate
  on hot key, remember the previous app, and re-activate it before sending `⌘V` (or on cancel).
* **Modifier bleed**: if `⌥` is still held when `⌘V` is synthesized the target gets `⌥⌘V`;
  `Paster` waits (up to ~1.2 s) for all modifiers to be released first, like CLCL's `paste_wait`.

## Roadmap

1. Import of Windows CLCL `history.dat` / `regist.dat`.
2. Format filter & priority pages (which formats to keep / show first).
3. Tools/plugin equivalents (shell scripts or AppleScript on an item, from the menu).
4. Localisation (CLCL ships ja/en/de/uk/zh readmes).

## License

MIT, same as upstream CLCL. `LICENSE` carries the original copyright notice of Ohno Tomoaki
as the license requires, plus `Copyright (c) 2026 UK Intis Telecom LTD (Andrey Insarov)` for the Keepit fork.
