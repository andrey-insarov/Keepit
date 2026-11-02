# Keepit security

A clipboard manager sees everything you copy, so it has to be clear about what it keeps, where, and
who can get at it. This page is the complete picture for Keepit. The code is open
([github.com/andrey-insarov/Keepit](https://github.com/andrey-insarov/Keepit)), so every claim here
can be checked against it.

## In one paragraph

Keepit stores your clipboard history and templates in one folder on your Mac and nowhere else. There
is no account, no cloud, no analytics, and the app makes exactly one kind of network request: the
daily update check against GitHub. Copies from password managers are never recorded. If you set a
password, everything on disk is AES-256-GCM encrypted with a key derived from that password; the key
exists only in memory, is wiped when Keepit locks, and can optionally be released by Touch ID from
the Secure Enclave. A 24-word recovery phrase is the only way back in if you forget the password —
Keepit itself cannot reset it.

## What is stored, and where

Everything lives in `~/Library/Application Support/Keepit/` (App Store edition: the app's container
under `~/Library/Containers/com.it.keep/`):

| File | Contents | Encrypted with a password? |
|------|----------|----------------------------|
| `history.json` | The clipboard history: text, RTF, HTML, PNG images, file lists, with date and source app | Yes |
| `templates.json` | The template tree, including per-template hot keys | Yes |
| `settings.json` | Settings: hot keys, limits, ignore list — no clipboard data | No |
| `vault.json` | Encryption metadata: PBKDF2 salt, a sealed verifier, the wrapped recovery material | — |

The history is written when it changes and read on launch. Without a password the JSON is plain
text on disk, protected only by your macOS account and FileVault. *Settings → Advanced → Open
Data Folder* shows the folder.

Keepit also writes to the macOS keychain — only the Touch ID entry described below — and registers
itself as a login item if you let it start at login.

## What is never recorded

- Anything copied from a known password manager: 1Password, Bitwarden, KeePassXC, MacPass,
  Strongbox, KeeWeb, LastPass, Dashlane, Enpass, Keeper, NordPass, RoboForm, Apple Passwords and
  Keychain Access. These bundle identifiers are built in and always active; you can add your own
  apps on *Settings → History*.
- Anything the copying app marks as concealed or transient (`org.nspasteboard.ConcealedType`,
  `org.nspasteboard.TransientType`). Password managers and many terminals set these.
- Anything copied while recording is paused (*Pause Recording for 10 Minutes* in the menu).
- Formats other than plain text, RTF, HTML, PNG and file lists.

Note that Keepit cannot tell a password typed into a form from any other text if the app that put it
on the clipboard did not mark it. Use the pause, or the ignore list, for such apps.

## Encryption

Turn on *Require password at launch* and the history and templates files are encrypted:

- **Key derivation**: PBKDF2-HMAC-SHA256 with 200 000 rounds and a random 16-byte salt, producing a
  256-bit key. The salt is stored in `vault.json`; nothing else derived from the password is written
  except a small GCM-sealed verifier that lets Keepit tell a wrong password from corrupt data.
- **Cipher**: AES-256-GCM (CryptoKit), a fresh random nonce per file write, authenticated — a
  modified file fails to open rather than decrypting to garbage.
- **Key in memory**: the 32 key bytes live in a page-locked (`mlock`) buffer that is never swapped
  out and is overwritten with `memset_s` when Keepit locks or quits. A CryptoKit key object is built
  only for the duration of one call and discarded.
- **Locking**: *Lock Keepit* (`⌥L`), quitting, and — on by default — the screen locking
  or the Mac sleeping wipe the key and unload the decrypted history and templates. After that nothing
  readable is in memory until you unlock again.
- **Password strength**: the password dialog shows an entropy estimate and explains it; Keepit does
  not enforce a minimum, because the recovery phrase and Touch ID are the usual way in.
- **Wrong attempts**: after several wrong passwords Keepit backs off with increasing delays, and
  after too many it quits (at launch) or stays locked.

Changing the password re-wraps the recovery material; the data files are re-encrypted with the new
key.

## Touch ID

With *Unlock with Touch ID* on, Keepit stores a copy of the data key in the keychain under an access
control of `kSecAttrAccessibleWhenUnlockedThisDeviceOnly` + `biometryCurrentSet`. That means:

- the entry is protected by the Secure Enclave and released only after a successful fingerprint;
- it never leaves this Mac (not backed up, not synced);
- it is invalidated automatically if the set of enrolled fingerprints changes.

The password keeps working as a fallback and is still required to change the password itself unless
you allow Touch ID for that too. Turning Touch ID off deletes the keychain entry.

## Recovery phrase

When you set a password Keepit generates 32 bytes of entropy and shows them once as a 24-word
BIP-39-style phrase (2048-word English list, 8-bit checksum to catch typos). A key derived from that
entropy (HKDF) wraps the data key, and the entropy is in turn wrapped by the data key, so:

- the phrase can unlock the data and let you set a new password if you forget the old one;
- changing the password does not change the phrase;
- *Recovery phrase → Create New…* (Settings → Security) issues new entropy and invalidates the old phrase.

The phrase itself is never written to disk. Print it, or keep it in a password manager. Without the
password, Touch ID on the same Mac, or the phrase, the data is unrecoverable by design — there is no
server-side reset and Keepit's authors cannot help.

## Backups

*Settings → Security → Backup → Export…* produces one `.keepit` file: a magic header, a format version, a random 16-byte
salt, and the LZFSE-compressed JSON of history, templates and preferences sealed with AES-256-GCM
under a PBKDF2 key from a password you choose for the file. The file is safe to keep on a cloud
drive; its password is independent of the app password. *Import…* verifies the
authentication tag before using anything.

## Permissions Keepit asks for

| Permission | Why | What happens without it |
|------------|-----|-------------------------|
| **Accessibility** | To send ⌘V to the app you were working in, and to find the text cursor so the menu opens there | Items are copied to the clipboard; you press ⌘V yourself; the menu opens at the pointer |
| **Touch ID / keychain** | Only if you enable Touch ID unlock | Password only |
| **Login item** | Launch at login (on by default, switchable on *General*) | Start Keepit by hand |

Keepit does not ask for Full Disk Access, Screen Recording, Input Monitoring, Contacts, Calendars,
Location or the camera, and does not use any of them. The Accessibility permission is powerful — it
is the same one window managers and automation tools need — which is why the app is signed and
notarized and the source is public.

## Network

The direct-download edition makes one request: once a day (and when you choose *Check for
Updates…*) it fetches the Sparkle appcast from GitHub Releases over HTTPS. Updates are verified with
an EdDSA (Ed25519) signature embedded in the app before they are installed; a download that does
not match is rejected. The App Store edition is updated by the App Store and makes no requests at
all.

No clipboard content, no usage data and no identifiers are ever sent anywhere. There is no crash
reporter and no analytics library in the binary.

## Code signing and verifying a download

Every release is built on GitHub Actions from a tagged commit, signed with the Developer ID of UK
Intis Telecom LTD, notarized by Apple and stapled. The release page carries, for each DMG, a
`.dmg.sig` (Sparkle EdDSA signature) and a `SHA256SUMS` file. To verify a download by hand:

```bash
shasum -a 256 -c SHA256SUMS --ignore-missing
spctl -a -vv -t install Keepit-2.11.0.dmg      # "accepted, source=Notarized Developer ID"
```

Homebrew installs the same DMG from the same release.

The signing keys never leave GitHub's `release` environment: only `v*` tags can deploy to it, the
build-and-test job that runs on every push and pull request has no access to secrets, and every
third-party action in the workflow is pinned to a commit hash rather than a movable tag.

## Uninstalling and data removal

*Settings → Advanced → Reset and uninstall → Uninstall…* removes the app bundle, the data folder, the
keychain entry, the login item and the Accessibility grant, after asking for the password or Touch
ID and a typed confirmation. Deleting the app by hand leaves the data folder in place — remove
`~/Library/Application Support/Keepit/` yourself if you want it gone.

## Input limits

Whatever lands on the clipboard is checked before it is stored, so a hostile or runaway copy cannot
exhaust memory or disk:

| What | Limit | Where |
|------|-------|-------|
| Text | 2 MB of UTF-8 (rich text / HTML up to 4× that); larger copies are not recorded | Settings → History |
| Images | 10 MB and 40 megapixels; the pixel count is read from the image header, the image is never decoded first | Settings → History |
| File lists | 1 000 paths | Settings → History |
| History | 1 000 text / 30 image items, 256 MB in total; the oldest go first | Settings → History |
| Templates | 5 000 items, 16 levels deep, names of 200 characters | fixed |
| Paste queue | 500 items per session | fixed |
| Backup files | 512 MB | fixed |
| Password | 256 characters; a prompt answer (`{input:}`) 10 000 | fixed |

## Limitations worth knowing

- The clipboard itself is readable by any app on your Mac; Keepit cannot change that. It can only
  make sure what it *stores* is protected.
- While Keepit is unlocked, the decrypted history is in its memory like in any running app. Locking
  on sleep and screen lock (on by default) keeps that window short.
- Encryption protects the files at rest. Someone with your macOS password and Keepit unlocked sees
  what you see.
- Items you paste leave Keepit's control the moment they land in another app.

## Reporting a vulnerability

Please use GitHub's private vulnerability reporting (*Security → Report a vulnerability* on the
repository) or write to admin@keep.it.com rather than opening a public issue. You will get an answer within a
few days, and a fix is released as soon as it is ready; credit is given if you want it.
