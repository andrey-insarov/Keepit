# Keepit – Clipboard Manager — Privacy Policy

_Effective: 1 November 2026. Publisher: UK Intis Telecom LTD, https://keep.it.com_

**Summary: Keepit does not collect, transmit, or share any data. Everything it stores stays on your Mac.**

## What Keepit does with your data

Keepit records what you copy to the clipboard (text, images, file references) so that you can paste it
again later, and stores the templates you create. This data is kept **only on your computer**, in
`~/Library/Application Support/Keepit/`. It is never sent to us or to anyone else.

## Encryption and access control

If you enable password protection, the clipboard history and templates are stored encrypted with
AES-256-GCM using a key derived from your password (PBKDF2-HMAC-SHA256). The password itself is never
stored. Optional Touch ID unlock keeps a copy of that key in the macOS keychain, protected by the
Secure Enclave. Optional recovery phrases are generated on your Mac and shown to you once; Keepit does
not keep them. We cannot recover your data if you lose both the password and the recovery phrase.

## Password managers and sensitive content

Keepit never records clipboard contents marked as concealed by the copying application, and it
ignores copies made from known password managers (1Password, Bitwarden, KeePassXC, Keychain Access,
Apple Passwords and others). You can add further applications to the ignore list.

## Permissions

- **Accessibility**: used only to paste the chosen item into the active application with ⌘V and to
  position the popup menu at the text cursor. Keepit does not read or monitor the contents of other
  applications.
- **Login item** (optional): starts Keepit when you log in.

## Network

Keepit makes no network connections. (The direct-download edition distributed outside the App Store
checks GitHub Releases for updates once a day; the App Store edition does not even do that.)

## Analytics, advertising, tracking

None. Keepit contains no analytics, crash reporting, advertising or tracking code, and no third-party
SDKs that collect data.

## Children

Keepit is a general-purpose utility and is not directed at children.

## Changes

If this policy ever changes, the new version will be published at https://keep.it.com/privacy with a
new effective date.

## Contact

insarov@intistele.com — UK Intis Telecom LTD
