# Changelog

## 2.7.2 — unreleased

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
