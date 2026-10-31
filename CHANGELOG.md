# Changelog

## Unreleased

- **Touch ID unlock** (Preferences → *Unlock with Touch ID*): the vault key is kept in the
  Secure-Enclave-backed keychain behind a biometry-only access control; the password stays as
  fallback. Needs a Team-ID-signed build.

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
