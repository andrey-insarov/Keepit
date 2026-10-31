# Releasing Keep it

1. Bump the version: edit `VERSION` (e.g. `2.2.0`), commit.
2. Tag and push: `git tag -a v2.2.0 -m "Keep it 2.2.0" && git push origin main v2.2.0`.
3. GitHub Actions builds, signs with Developer ID, notarizes with Apple, staples the ticket and
   attaches `Keepit-2.2.0.dmg` and `Keepit-2.2.0.zip` to the GitHub Release for the tag.

`CFBundleShortVersionString` comes from `VERSION`; `CFBundleVersion` is the commit count
(`git rev-list --count HEAD`), so every build has a unique, increasing build number.

## One-time setup for signing and notarization (Apple Developer account)

### A. Developer ID Application certificate → secret `MACOS_CERT_P12`

1. Xcode → Settings → Accounts → your Apple ID → *Manage Certificates…* → **+** →
   *Developer ID Application*. (Or at developer.apple.com → Certificates → + → Developer ID
   Application, upload a CSR from Keychain Access.)
2. Keychain Access → *My Certificates* → right-click **Developer ID Application: Your Name (TEAMID)**
   → *Export…* → format `.p12`, set an export password.
3. `base64 -i DeveloperID.p12 | pbcopy` → GitHub repo → Settings → Secrets and variables → Actions →
   *New repository secret*:
   * `MACOS_CERT_P12` — the base64 text
   * `MACOS_CERT_PASSWORD` — the export password

### B. App Store Connect API key (for `notarytool`) → secrets `APPSTORE_*`

1. https://appstoreconnect.apple.com → Users and Access → *Integrations* → *App Store Connect API*
   → **Team Keys** → **+** → name `Keepit CI`, access **Developer**. Download the `.p8` file
   (only possible once).
2. Secrets:
   * `APPSTORE_KEY_ID` — the Key ID shown next to the key (10 characters)
   * `APPSTORE_ISSUER_ID` — the Issuer ID at the top of that page (UUID)
   * `APPSTORE_PRIVATE_KEY` — the full contents of the `.p8` file, including the BEGIN/END lines

With all five secrets present the workflow signs + notarizes; without them it builds ad-hoc
(forks and pull requests keep working).

### Local signed build

```bash
# once: store notarization credentials in the keychain
xcrun notarytool store-credentials "keepit-notary" --key AuthKey_XXXXXXXXXX.p8 --key-id XXXXXXXXXX --issuer <issuer-uuid>

make notarize SIGN_ID="Developer ID Application: Your Name (TEAMID)" NOTARY_PROFILE=keepit-notary
make dist     SIGN_ID="Developer ID Application: Your Name (TEAMID)"
spctl -a -vv -t install Keepit-*.dmg      # should say "accepted, source=Notarized Developer ID"
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
   (note: "Keep It" is taken by another developer — use e.g. "Keepit" with subtitle
   "Clipboard History & Templates"), primary language, bundle id `com.it.keep`, SKU `keepit-mac`.
   Fill in: description, keywords, support URL, **privacy policy URL** (required), category
   *Productivity*, screenshots (1280×800 or 1440×900 or 2560×1600, at least one), age rating,
   App Privacy ("Data Not Collected" — Keep it sends nothing anywhere).

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

Review notes worth adding (App Review Information → Notes): Keep it is a clipboard history
manager; it asks for the Accessibility permission only to paste the chosen item into the active
app with ⌘V and to position the popup at the text cursor; without it the app still works
(items are copied to the clipboard). Nothing leaves the Mac; history can be password-protected
and is stored AES-GCM encrypted.

Expect the sandbox to block one thing: the Viewer's "open file" from a FILE LIST item works only
for files the user picked through a panel in this session; other paths open in Finder instead.
