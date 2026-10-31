# Changelog

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
