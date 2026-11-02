# Releasing Keepit

1. Bump the version: edit `VERSION` (e.g. `2.2.0`), commit.
2. Tag and push: `git tag -a v2.2.0 -m "Keepit 2.2.0" && git push origin main v2.2.0`.
3. GitHub Actions runs the `build` job (tests, ad-hoc build, UI smoke test), then the `release` job
   waits for approval: Actions → the run → **Review deployments** → `release` → Approve.
4. The release job signs with Developer ID, notarizes with Apple, staples the ticket, signs the
   Sparkle appcast and attaches `Keepit-2.2.0.dmg`, `.zip`, `.dmg.sig`, `SHA256SUMS` and
   `appcast.xml` to the GitHub Release for the tag, then bumps the Homebrew cask on `main`.

`CFBundleShortVersionString` comes from `VERSION`; `CFBundleVersion` is the commit count
(`git rev-list --count HEAD`), so every build has a unique, increasing build number.

## One-time setup for signing and notarization (Apple Developer account)

All secrets below live in the GitHub **environment `release`** (Settings → Environments), never as
repository secrets: only `v*` tags may deploy to it, it requires a reviewer, and the `build` job that
runs on every push and pull request cannot read them. Add a secret with
`gh secret set NAME --env release -R andrey-insarov/Keepit` (reads the value from stdin or a prompt).
Keep the originals (`.p12` + its password, `.p8` + Key ID + Issuer ID, the Sparkle private key) in a
password manager — GitHub cannot show a secret again once it is stored.

### A. Developer ID Application certificate → secret `MACOS_CERT_P12`

1. Xcode → Settings → Accounts → your Apple ID → *Manage Certificates…* → **+** →
   *Developer ID Application*. (Or at developer.apple.com → Certificates → + → Developer ID
   Application, upload a CSR from Keychain Access.)
2. Keychain Access → *My Certificates* → right-click **Developer ID Application: Your Name (TEAMID)**
   → *Export…* → format `.p12`, set an export password.
3. Environment secrets:
   * `MACOS_CERT_P12` — `gh secret set MACOS_CERT_P12 --env release < <(base64 -i DeveloperID.p12)`
   * `MACOS_CERT_PASSWORD` — the export password

### B. App Store Connect API key (for `notarytool`) → secrets `APPSTORE_*`

1. https://appstoreconnect.apple.com → Users and Access → *Integrations* → *App Store Connect API*
   → **Team Keys** → **+** → name `Keepit CI`, access **Developer**. Download the `.p8` file
   (only possible once).
2. Secrets:
   * `APPSTORE_KEY_ID` — the Key ID shown next to the key (10 characters)
   * `APPSTORE_ISSUER_ID` — the Issuer ID at the top of that page (UUID)
   * `APPSTORE_PRIVATE_KEY` — the full contents of the `.p8` file, including the BEGIN/END lines

The `release` job needs all five; the `build` job never signs, so forks and pull requests keep
working without any secrets.

### C. Developer ID provisioning profile (for Touch ID unlock) → secret `MACOS_DEVID_PROFILE`

Touch ID unlock stores the vault key in the data-protection keychain, which needs the
`com.apple.application-identifier` / `keychain-access-groups` entitlements — and macOS only lets a
Developer ID app carry those when a provisioning profile is embedded (otherwise launchd refuses to
start it, "error 163").

1. developer.apple.com → Identifiers → + → App IDs → macOS → bundle id `com.it.keep` (same App ID
   the App Store build uses).
2. Profiles → + → under *Distribution* choose **Developer ID** → select the App ID → select the
   Developer ID Application certificate → name `Keepit Developer ID` → Generate → Download.
3. Save it as `Resources/KeepitDevID.provisionprofile` (git-ignored). `make app`/`make install` with
   a `SIGN_ID` now embeds it and enables Touch ID.
4. For CI: `gh secret set MACOS_DEVID_PROFILE --env release < <(base64 -i Resources/KeepitDevID.provisionprofile)`.

Without the profile everything else works; Preferences explains that Touch ID needs the signed build.

### Local signed build

```bash
# once: store notarization credentials in the keychain
xcrun notarytool store-credentials "keepit-notary" --key AuthKey_XXXXXXXXXX.p8 --key-id XXXXXXXXXX --issuer <issuer-uuid>

make notarize SIGN_ID="Developer ID Application: Your Name (TEAMID)" NOTARY_PROFILE=keepit-notary
make dist     SIGN_ID="Developer ID Application: Your Name (TEAMID)"
spctl -a -vv -t install Keepit-*.dmg      # should say "accepted, source=Notarized Developer ID"

# day-to-day: pull and install a signed build into /Applications
git pull && make install SIGN_ID="Developer ID Application: Your Name (TEAMID)"
```

Signed and App Store builds are **universal** (arm64 + x86_64; `UNIVERSAL=0` for a quick
single-arch build). The Makefile asks SwiftPM for the product path (`--show-bin-path`), so it
works across toolchains. On CI a non-universal result fails the build; locally it only warns.

Convenient alias for `~/.zshrc`:

```bash
alias keepit-build='cd ~/keepit && git pull && make install SIGN_ID="Developer ID Application: UK Intis Telecom LTD (WQ66955SW2)"'
```

### What the signed build changes for users

* No Gatekeeper warning when opening the DMG or the app.
* The Accessibility grant survives updates, because the signature (team + bundle id) is stable.
* *Launch at login* (SMAppService) works reliably; it is flaky for ad-hoc signed bundles.

## Troubleshooting

* `notarytool` says *Invalid* → `xcrun notarytool log <submission-id> --keychain-profile keepit-notary`
  shows why; the usual causes are a missing `--timestamp`/hardened runtime (already set in the
  Makefile) or a stale certificate.
* The Finder window layout step of `make dmg` is best effort and is silently skipped on CI.

## Sparkle auto-updates (GitHub Releases)

Keepit checks `https://github.com/andrey-insarov/Keepit/releases/latest/download/appcast.xml`
once a day (and via *Check for Updates…*). Each release's DMG is signed with a Sparkle EdDSA key
and listed in `appcast.xml`, which CI attaches to the release.

One-time setup:

1. Build once so the Sparkle tools exist: `swift build`.
2. Generate the key pair (stored in your login keychain):
   `$(find .build -type d -name bin -path "*parkle*" | head -1)/generate_keys`
   It prints the **public** key (base64). Put it in a file named `SPARKLE_PUBLIC_KEY` in the
   project root (git-ignored) — `make app` injects it into Info.plist — and in GitHub →
   `gh variable set SPARKLE_PUBLIC_KEY --env release --body "<public key>"`.
3. Export the **private** key for CI: `…/generate_keys -x sparkle_ed25519` → contents of that
   file → `gh secret set SPARKLE_PRIVATE_KEY --env release < file`. Delete the exported file afterwards
   (the private key is the one thing that cannot be replaced: installed copies only accept updates
   signed by it, so keep it in a password manager).
4. Tag a release. The *Sparkle appcast* step signs the DMG and attaches `appcast.xml`.

A build without the public key simply has no *Check for Updates…* item. Apps already installed
only learn about updates from the first release that ships an appcast, so the first Sparkle-enabled
version has to be installed by hand once.

## Mac App Store

The App Store build is sandboxed (`Resources/Keepit-AppStore.entitlements`) and packaged as a
signed `.pkg` by `make appstore`. One-time setup:

1. **App ID**: developer.apple.com → Identifiers → + → App IDs → macOS, bundle id `com.it.keep`,
   no extra capabilities needed.
2. **Certificates** (Xcode → Settings → Accounts → Manage Certificates, or developer.apple.com):
   *Apple Distribution* (signs the app) and *Mac Installer Distribution* (signs the .pkg).
3. **Provisioning profile**: developer.apple.com → Profiles → + → *Mac App Store Connect*,
   select the App ID and the distribution certificate, download, save as
   `Resources/Keepit.provisionprofile` (it is git-ignored).
4. **App Store Connect record**: appstoreconnect.apple.com → My Apps → + → macOS, name
   (the name is **Keepit – Clipboard Manager**; plain "Keep It" belongs to another developer), primary language, bundle id `com.it.keep`, SKU `keepit-mac`.
   Fill in: description, keywords, support URL, **privacy policy URL** (required), category
   *Productivity*, screenshots (1280×800 or 1440×900 or 2560×1600, at least one), age rating,
   App Privacy ("Data Not Collected" — Keepit sends nothing anywhere).

Build and upload:

```bash
make appstore VERSION=$(cat VERSION) TEAM_ID=XXXXXXXXXX \
  APP_SIGN_ID="Apple Distribution: UK Intis Telecom LTD (XXXXXXXXXX)" \
  PKG_SIGN_ID="3rd Party Mac Developer Installer: UK Intis Telecom LTD (XXXXXXXXXX)"
```

Upload `Keepit-<version>-appstore.pkg` with **Transporter** (free, Mac App Store) — drag the
.pkg in, Deliver — or from the terminal with the App Store Connect API key:

```bash
xcrun altool --upload-package Keepit-2.1.0-appstore.pkg --type macos \
  --apple-id <App Store Connect app Apple ID> --bundle-id com.it.keep --bundle-version <build> \
  --bundle-short-version-string 2.1.0 --apiKey XXXXXXXXXX --apiIssuer <issuer-uuid>
```

Then in App Store Connect: select the build under the version → *Submit for Review*.
Each submission needs a new, higher `CFBundleVersion` (the commit count does that automatically).

Review notes worth adding (App Review Information → Notes): Keepit is a clipboard history
manager; it asks for the Accessibility permission only to paste the chosen item into the active
app with ⌘V and to position the popup at the text cursor; without it the app still works
(items are copied to the clipboard). Nothing leaves the Mac; history can be password-protected
and is stored AES-GCM encrypted.

Expect the sandbox to block one thing: the Viewer's "open file" from a FILE LIST item works only
for files the user picked through a panel in this session; other paths open in Finder instead.

## Off-site mirror (Codeberg)

`https://codeberg.org/itcom/Keepit` is a push mirror: the `mirror` job pushes every branch and tag
after each push to `main` or a tag (Codeberg itself no longer offers pull mirrors). One-time setup:

1. `ssh-keygen -t ed25519 -f ~/Desktop/codeberg_keepit -N "" -C "github-actions mirror"`
2. Codeberg → repo → Settings → **Deploy keys** → Add: paste `codeberg_keepit.pub`, tick
   **Enable write access**.
3. `gh secret set CODEBERG_DEPLOY_KEY -R andrey-insarov/Keepit < ~/Desktop/codeberg_keepit`
   (a repository secret is fine: the key can only write to that one Codeberg repository).
4. Delete both files from the Desktop (keep a copy in the password manager if you like; a lost key
   is simply replaced by a new deploy key).

Note `git push --mirror` makes Codeberg identical to GitHub, including deleting branches that were
deleted here — do not push to the mirror by hand.

