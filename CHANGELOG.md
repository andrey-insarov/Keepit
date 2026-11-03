# Changelog

## Unreleased

- `keepit://`: a URL with a repeated parameter name (`?text=a&text=b`) crashed the handler; it is now refused. Senders are no longer trusted just for being identifiable: the first state-changing command from each app asks, *Always Allow* puts the app on a trusted list (Settings → Advanced → *Forget Trusted Apps* clears it); a browser or an unidentified sender asks every time. The sender PID comes from `keySenderPIDAttr`
- On-screen keyboard: wording corrected. `NSWindow.sharingType = .none` is deprecated and not guaranteed by Apple — the panel *asks* to stay out of screen capture, which current macOS honours; the protection you can count on is the absence of keyboard events and the shuffled keys. Comments, tooltip, guide and security page now say so

## 2.13.0 — 2026-11-03

- **On-screen keyboard for the password.** The keyboard button next to the password field opens a small panel with shuffled keys; the panel is excluded from screenshots, screen recording and screen sharing, and clicks go straight into the protected buffer without key events, so keyloggers see nothing. Shift, symbols, backspace, *Shuffle*
- Password dialog: *OK* is enabled only once a password is typed and, when setting one, once both fields match — checked as you type, from either keyboard. The text no longer claims "there is no recovery": the recovery phrase follows right after
- First-run dialog is narrower: the Touch ID checkbox lost its parenthesis and the recovery-phrase sentence is gone (the phrase has its own dialog right after)
- **`keepit://` URL commands are off by default** — Settings → Advanced → Automation → *Allow keepit:// URL commands*. Any app or web page can open a URL, and `add` / `paste` act on the clipboard and the front app without confirmation, so the scheme is now opt-in. **If you drive Keepit from Shortcuts, Raycast or Alfred, turn it on after updating.** While off, such URLs are ignored with a beep. While on, Keepit checks who opened the URL: a web browser, or a sender macOS cannot name, gets a confirmation dialog showing the full URL before any state-changing command runs; Shortcuts, Raycast, Alfred and Terminal run directly
- Settings → Menu: *Items in menu* — how many of the latest entries the history menu lists (60 by default, up to 200). The setting existed in `settings.json` since 2.0 but had no field in Settings

## 2.12.0 — 2026-11-03

Security and robustness release after an external review of 2.11.1, plus one new option.

- **Update checks are optional.** Settings → General → Updates → *Check for updates automatically* (direct-download edition). Off, Sparkle is not started at all — no scheduled check, no check on demand — and *Check for Updates…* leaves the menus; Keepit then makes no network request whatsoever. Default on. The App Store edition has no updater and no such option

- **Password-manager exclusion closes the copy-then-switch gap.** Which app wrote the clipboard was taken to be whatever was in front when Keepit noticed the change — wrong when you copy in a password manager and ⌘Tab away within one poll interval. Keepit now considers every app that was in front since its last look, and skips the change if any of them is a password manager or on your ignore list. Also: after a pause or unlock, the last thing copied while recording was off is no longer recorded
- **Saving no longer blocks the interface.** Each history change re-encoded, encrypted and rewrote the whole history on the main thread — a visible pause with a large history. Debounced saves now run on a background queue (lock, quit and password changes still wait for the file). Data files are written as compact JSON; `settings.json` stays readable
- **Vault format 2**: `vault.json` records the KDF name and round count, so parameters can change in a future version without breaking existing vaults. Vaults from earlier versions open unchanged. Return codes of the system RNG and PBKDF2 are checked instead of assumed; a refused `mlock` is logged
- **Sparkle is pinned**: `Package.resolved` is committed and both CI jobs refuse to build if dependency resolution drifts from it, so a new Sparkle release never enters a signed Keepit build without a reviewed commit
- System log: diagnostics go through `os.Logger` (subsystem `com.it.keep`) instead of `NSLog`; only errors and unexpected states are logged, every inserted value is private, and a decode failure no longer quotes the error's description (which could include a character from the file). The security page now has a *System log* section and a note on macOS 15.4's pasteboard-access list
- Support form: the size limit is enforced on what was actually received, not only on `Content-Length`; attachments are identified by their bytes, not the declared type
- keep.it.com sends HSTS, Content-Security-Policy, X-Frame-Options, Permissions-Policy and Cross-Origin-Opener-Policy
- Docs: the security page separates what is reliable (a concealed mark set by the copying app) from what is best effort (exclusion by app); README, landing page, guide, privacy policy and App Store listing use the same wording; the README no longer says "there is no recovery" above the recovery-phrase section
- App Store build: Advanced shows *Reset…* only (the sandbox cannot move the app to the Trash; store apps are removed from Launchpad)
- `keepit://settings` opens Settings (replaces `keepit://preferences`)

## 2.11.1 — 2026-11-02

- Hardening: images are checked by byte size *and* pixel count from the header before anything is decoded (40 MP cap), the paste queue stops at 500 items, a `{input:}` answer at 10 000 characters; the full table is on the security page
- Cleanup: dead code and 39 localization strings left over from the old Preferences window removed from all 21 languages
- Fix: quitting or updating Keepit while it was locked (password set, *Lock when the screen locks or the Mac sleeps*) wrote the empty in-memory history and templates over the files on disk — and in plain text, since the key was already gone. Nothing is written while locked now, and an encrypted file is never replaced by plaintext
- Backup (Export… / Import…) moved from Security to General — it is housekeeping, not protection
- Unlock dialog: narrower field and buttons; the third button is *Recovery Access…*
- Preview panel: placed next to the menu as it actually sits on screen (it used to overlap the menu bar or slide under the menu when macOS had shifted the menu), with rounded corners to match
- Guide: every screenshot retaken for the 2.11 Settings window, the paste queue and the Examples templates

## 2.11.0 — 2026-11-02

- **Settings, the Mac way.** *Preferences* is now *Settings* (as in macOS 13+), with a toolbar of panes — General, Shortcuts, Paste Queue, History, Menu, Security, Advanced — and the window sized to each pane. Every change applies immediately; there is no Save or Cancel, ⌘W or Esc closes
- Number fields have a stepper and a unit word (seconds, characters, pixels, items) and refuse values out of range; a shortcut that collides with another command is refused on the spot with the reason shown under the fields
- Ignored apps are a list with icons: **+** picks an app from Applications (the bundle identifier is read from it), **−** removes, double-click edits an identifier by hand
- Labels follow Apple's wording: *Shortcuts* instead of *Hot keys*, *Pause recording*, buttons carry the action and group titles the meaning (Password → *Change…*, Backup → *Export…* / *Import…*, Recovery phrase → *Create New…*); the window title is the pane name
- Menu: *Settings…* (⌘,) replaces *Preferences…*
- Paste queue keys are now `⌥N` (start / stop) and `⌥⇧N` (paste all remaining); `⌥V` stays. Settings still on the 2.10 defaults are moved automatically
- Advanced → *Reset…* puts Keepit back to a fresh install (history, templates, settings, password, Touch ID key) without touching the app or its permissions; *Uninstall…* does that and removes the app
- Reset runs the same welcome as a fresh install: the password offer, then the Accessibility prompt if needed
- Viewer: toolbar buttons that make no sense for the selection are disabled — *Add to Template* on a template, *New Folder* outside Template, *Delete* on a group heading, *Send to Clipboard* on the clipboard itself, *Insert* unless a text template is being edited; *Delete* on the clipboard empties it
- Shortcut fields no longer start recording just because the pane gave them keyboard focus — click them, or press Space
- A fresh install (and Reset) starts with an *Examples* template folder that shows placeholders at work — a greeting with `{input:Name}` and `{cursor}`, today's date, a clipboard quote, a signature — in the system language

## 2.10.1 — 2026-11-02

- Preferences: the paste queue has its own tab (keys, idle time, separator); on *Hot keys* the *Other* section is one straight column, so every field lines up

## 2.10.0 — 2026-11-02

- **Paste queue** — serial copy-and-paste. `⌥N` starts it; every ⌘C adds to a counter next to the menu bar icon (`● 3`); `⌥V` pastes the items back one by one in the order they were copied; `⌥⇧N` pastes everything left, joined with a line break, tab, space or nothing. The queue ends by itself after the last item or after two minutes without activity (adjustable), ⌘V works as always, and while it is on the history menu marks its items (▶ next, ○ queued, ✓ pasted)
- The Viewer's default hot key is now `⌥E`; `⌥V` belongs to the paste queue. Existing settings that had the Viewer on ⌥V are moved to ⌥E automatically
- Preferences → Hot keys: a *Paste queue* block (three keys, idle time, separator); *Reset to Defaults* now also refills the Viewer / Preferences / Clear History / Quit fields instead of blanking them

## 2.9.3 — 2026-11-02

- Fix: 2.9.2 was built without the Developer ID provisioning profile, so Touch ID unlock stopped working and Keepit asked for the password. This build restores it; the release job now refuses to run without the profile

## 2.9.2 — 2026-11-02

- Preferences: a **?** button in the bottom-left corner opens the online user guide
- Screenshots on keep.it.com and in the guide show the 2.9.1 menu (⌥ keys, ⌃⌥ numbers) and the Viewer search
- Releases are now built in a protected GitHub environment: signing keys are available only to `v*` tags after manual approval, the build-and-test job runs without secrets, third-party actions are pinned to commit hashes (see [security.html](https://keep.it.com/security.html))

## 2.9.1 — 2026-11-01

- Viewer: **Insert ▾** in the toolbar lists every template placeholder with a description and puts the chosen one at the cursor; **?** opens the online user guide. Up/Down and the hex dump moved to the context menu; the toolbar has no gaps
- Fix: a template with `{input:…}` / `{choice:…}` was expanded but not pasted — the target app now gets time to come back after the dialog
- Fix: the Help menu added in 2.9.0 was unreachable (a menu-bar app has no menu bar); the in-app placeholder reference window is gone, the guide replaces it
- The placeholder dialog shows the template name without the `&` shortcut marker; *Show in Viewer* clears the Viewer search first
- **New default hot keys**: ⌥M history menu, ⌥V Viewer, ⌥S Preferences, ⌥C Clear History, ⌥P pause/resume, ⌥L lock, ⌥Q quit (⌥T templates unchanged); every global key is shown next to its command in the menu. Existing settings keep their keys — a new default that collides with one you already use stays off until you assign it. While a menu is open, global keys pause so an action never fires twice
- Fix: after previewing a large image the preview panel stayed huge for every item; images are capped at the panel size
- User guide and security page: keep.it.com/guide.html, keep.it.com/security.html (docs/GUIDE.md, docs/SECURITY.md)

## 2.9.0 — 2026-11-01

- Viewer: search field (⌘F) filtering history and templates; bold section titles and clipboard item, heavier disclosure chevrons. The latest item is bold in the history menu
- **Hot keys tab** in Preferences with every global shortcut in one place and *Reset to Defaults*; conflicts between them are caught on Save
- New global hot keys: **⌃⌥1–9, 0 — paste history item 1–10 directly**; **⌃⌥ + V/U/L/T/S/W/J/A/⌫ — act on the latest item** (plain text, UPPERCASE, lowercase, Title Case, Sentence case, trim, single line, add to Templates, delete); optional *Lock Keepit* and *Pause / resume recording* (off by default). The menu shows exactly these keys: a shortcut is either always available or not shown, so the menu-only ⌥/⌃ alternates are gone (the extended menu covers them)
- Export/Import Backup moved out of the menus into Preferences → Security
- **`keepit://` URL scheme** for Shortcuts, Raycast, Alfred and scripts: `keepit://paste/2`, `keepit://copy/3`, `keepit://template/Name`, `keepit://add?text=…`, `keepit://add-template?text=…&name=…`, `keepit://history`, `keepit://pause` … (see the user guide)
- **Placeholders in templates** — `{date}`, `{date+7d:EEEE}`, `{time}`, `{clipboard}`, `{clipboard:2|upper}`, `{input:Name}`, `{choice:A|B}`, `{cursor}`, `{user}`, `{uuid}`, `{random:1-100}` and more (see the user guide); `{input}`/`{choice}` ask for values before pasting, `{cursor}` places the caret
- **Extended menu (hold ⇧)**: every history item gets a submenu with all actions for it — Paste, Paste as plain text, Copy only, *Paste as* UPPERCASE / lowercase / Title Case / Sentence case / trimmed / single line, Add to Templates, Show in Viewer, Delete — with single-letter shortcuts. The ⇧ “plain text” alternate is folded into it (⌥ and ⌃ alternates stay)
- New hot key **⌥⇧V — Paste previous item**: pastes history item #2 without opening the menu (press again to swap back); changeable or switchable off on the General tab
- Preview panel no longer pops up for short single-line text (the menu line already shows it all)
- Short checkbox labels with (?) help buttons that open explanations in a popover; ignored-apps field aligned with the other rows
- Preferences reorganised into five tabs — General, History, Menu, Security, Advanced — in a
  fixed-size window; Export/Import Backup also live on the Security tab, *Open Data Folder* and
  the Danger zone on Advanced.

## 2.8.0 — 2026-11-01

- **Pause Recording for 10 Minutes** in the menu (the menu-bar icon turns into ⏸); *Resume Recording*
  ends it early. Survives lock/unlock.
- **Delete from the menu**: hold ⌃ while choosing a history item to remove it (⌃1, or ⌃⌘1 with
  the search field).
- **Auto-expiry**: Preferences → History → *Forget items older than* 1 h / 6 h / 1 day / 1 week /
  30 days. Old items are dropped on every change and once a minute by a timer.
- **Source app icons**: text and file items in the history menu carry the icon of the app they were
  copied from (Preferences → Menu).
- **Preview panel**: hovering a history item shows the full image or the first lines of the text in a
  floating panel beside the menu, with source app, date and size. Replaces tooltips while on
  (Preferences → Menu).
- Password prompts show the current keyboard layout (EN, RU, …) and a red Caps Lock warning, live.
- The password-strength hint no longer gets cut off.
- *Delete Keepit and All Data* notices a Homebrew install and tells you how to clear brew's record
  (`brew uninstall --cask --force keepit`), so a later `brew install` does not fail.

## 2.7.1 — 2026-11-01

- Touch ID is always offered on first run and as soon as *Require password* is ticked in Preferences.
  A closed MacBook lid or a sleeping Magic Keyboard makes macOS report Touch ID as unavailable for a
  moment; Keepit now keeps the setting and stores the key at the next password unlock instead of
  silently dropping the option.
- Homebrew cask: current `depends_on macos:` syntax (no more deprecation warning).

## 2.7.0 — 2026-11-01

- **Pin in one move**: hold ⌥ while choosing a history item to add it to Templates (root level)
  instead of pasting it.
- **Homebrew**: `brew tap andrey-insarov/keepit https://github.com/andrey-insarov/Keepit && brew install
  --cask andrey-insarov/keepit/keepit`. The cask lives in `Casks/` and CI bumps it on every release.
- **Paste as plain text**: hold ⇧ while choosing a history item (or add ⇧ to its shortcut) to paste
  without RTF/HTML formatting.
- **Search in the history menu**: a search field at the top of the menu; typing filters the list in
  place, Return pastes the first match, ⌘1–⌘0 pick by number. Can be turned off in Preferences →
  Menu (then the old 1-9/0/A-Z shortcuts are back).
- Default text/file history raised from 100 to 1000 items for new installs (≈10–30 MB; the
  image ring stays at 30). Existing settings are not changed.
- 11 more interface languages: Brazilian Portuguese, Korean, Traditional Chinese, Turkish, Polish,
  Dutch, Hebrew, Czech, Lithuanian, Latvian and Estonian (21 in total). Terminology cross-checked
  against community-localized macOS apps (Maccy, Rectangle) and Apple's own wording; *Clear History*
  now follows Safari's term in German, Spanish, Italian and Simplified Chinese. Baltic languages name
  the System Settings panes in English too, since macOS has no UI in those languages.

## 2.6.0 — 2026-11-01

- Preferences → **Danger zone → Delete Keepit and All Data…**: a complete uninstall from inside the
  app. Requires the password or Touch ID (when protection is on), then typing `DELETE` and ticking
  the acknowledgement. Removes the data folder, the Touch ID keychain item, the defaults domain
  (Sparkle state), caches, the login item and the Accessibility grant, and moves the app to the Trash.
- Preferences window scrolls when taller than the display; related numeric fields and the two hot
  keys now share a row.
- First launch: Keepit offers to set a password (with Touch ID, ticked by default on Macs that
  have it) right away and says plainly that without one the
  data is stored unencrypted; *Launch at login* is on by default for new installs.
- Accessibility: Keepit no longer triggers the system “would like to control this Mac” sheet (it
  stayed on screen after the switch was flipped and had to be dismissed with *Deny*). The button
  opens the Accessibility pane directly, with Keepit already listed.

## 2.5.2 — 2026-11-01

- Menu: separator before *Check for Updates…* / *About Keepit*.

## 2.5.1 — 2026-11-01

- Fixed Sparkle updates failing with “An error occurred while running the updater” (launchd 163):
  the app signature no longer pushes the app's Team-ID entitlements onto Sparkle's `Autoupdate`,
  `Updater.app` and XPC services (no `--deep`; helpers signed individually, keeping their own
  entitlements). 2.4.0 → 2.5.0 in-app updates were affected; install 2.5.1 from the DMG once.

## 2.5.0 — 2026-11-01

- **Backup export / import** (menu → *Export Backup…* / *Import Backup…*): history, templates and
  optionally preferences in one `.keepit` file, LZFSE-compressed and AES-256-GCM encrypted with a
  password you choose at export time (PBKDF2, independent of the vault password). Import can
  *Merge* (adds what is missing; templates land in an “Imported <date>” folder) or *Replace*.
  This is also the way to move data between the App Store and direct-download editions.
- **Localization**: Russian, Ukrainian, German, French, Spanish, Italian, Japanese, Simplified Chinese and Arabic. Keepit
  follows the macOS system language; English remains the base. `Scripts/gen_strings.py` holds the
  translation table and regenerates the `.lproj` files.
- Viewer: no more thick blue focus ring around the tree and content panes.
- Releases now include a detached EdDSA signature (`.dmg.sig`) and `SHA256SUMS`.
- New *About Keepit* window (icon, version with git commit and build date, Help, link to
  keep.it.com); the menu-bar menu lists it after *Check for Updates…* instead of the version line.
- Distribution builds (DMG, App Store) are now universal (Apple silicon + Intel); earlier
  releases were arm64-only. Ad-hoc local builds stay single-arch (`make app UNIVERSAL=1` to force).
- Fixed the app icon showing as colour noise in the Touch ID dialog: the `.icns` now has Apple's
  canonical layout (ARGB `ic04`/`ic05` + Retina PNGs, no legacy `icp*` entries) and on a Mac
  it is built with `iconutil` from the committed iconset.

## 2.4.0 — 2026-10-31

- Automatic updates via Sparkle 2 (daily check of GitHub Releases, *Check for Updates…* in the
  menu, EdDSA-signed downloads).

## 2.3.0 — 2026-10-31

- **Recovery phrase**: when protection is turned on, Keepit shows a 24-word phrase (BIP-39 word
  list, checksummed) that can unlock the data on any Mac if the password is forgotten; it can be
  printed or saved as PDF, and the dialog requires acknowledging that losing both the password
  and the phrase means the data is gone. The phrase stays valid across password changes;
  Preferences → *New Recovery Phrase…* issues a new one (the old one stops working) and, since a leaked phrase exposes the current key, offers to change the password right away. The unlock prompt offers
  *Use Recovery Phrase…*, after which a new password must be set.
- Password strength meter (Weak / Fair / Good / Excellent with a hint) under the new-password
  field, computed on the locked bytes — still no String of the password anywhere.
- History is two rings: text & files (default 100) and images (default 30), each dropping its
  own oldest entries; the Viewer shows them as *Text & files* and *Images* groups and Preferences
  has both limits.
- Input hardening: clipboard texts over 2 MB, file lists over 1000 entries and images over
  10 MB are not recorded; the history is capped at 256 MB in total; the popup menu shows at most
  60 history items; passwords are limited to 256 characters; wrong-password attempts are slowed
  down (1/2/4 s) and locked out for 30 s after three misses; template names ≤ 200 chars,
  tree depth ≤ 16, ≤ 5000 items, ≤ 50 template hot keys; data files over 512 MB are refused;
  all numeric settings are clamped to sane ranges. (`Core/Limits.swift`)
- **Change password with Touch ID** (default on; Preferences → *Allow changing the password with
  Touch ID* can be turned off to always require the current password).

## 2.2.0 — 2026-10-31

- **Touch ID unlock** (Preferences → *Unlock with Touch ID*): the vault key is kept in the
  Secure-Enclave-backed keychain behind a biometry-only access control (invalidated if
  fingerprints change); the password stays as fallback on every prompt. Available in the signed
  release build (it needs the embedded Developer ID provisioning profile).

## 2.1.2 — 2026-10-31 (security)

- Copies made in known password managers (KeePassXC, MacPass, Strongbox, KeeWeb, 1Password,
  Bitwarden, LastPass, Dashlane, Enpass, Keeper, NordPass, RoboForm, Keychain Access, Apple
  Passwords) are never recorded, regardless of settings. KeePassXC's "concealed" marker does not
  reach the macOS pasteboard in the standard form, so 2.1.1 and earlier recorded passwords copied
  from it. **If you used an earlier version with a password manager, review and delete those
  history entries in the Viewer.**
- Pasteboard types whose name mentions "concealed" or "password" are also ignored.

## 2.1.1 — 2026-10-31

Fixes from the first live test session.

- Viewer: template items and folders now have a **Name** field above the content (hints for
  `-` separators and `&x` shortcuts); *New Item* focuses it first.
- Viewer / Preferences: text editors fill their pane — clicking anywhere in the pane focuses them
  (an empty item used to show a one-line editor that was easy to miss).
- When the Accessibility permission is missing, choosing a menu item now explains that the text
  was copied and how to enable auto-paste, instead of failing silently.
- Menu thumbnails fit a 4:1 box (default height 40 px) so wide screenshots stay recognisable.
- Build: `stapler` retries on Apple ticket-service hiccups; signed local builds documented.

## 2.1.0 — 2026-10-31

First public release: history, hot-key menus, auto-paste, templates, Viewer, password protection
with AES-GCM encrypted storage and key zeroization, Developer ID signed and notarized DMG.
