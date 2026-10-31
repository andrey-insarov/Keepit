# Releasing Keep it

1. Bump the version: edit `VERSION` (e.g. `2.2.0`), commit.
2. Tag and push: `git tag v2.2.0 && git push origin main --tags`.
3. GitHub Actions builds `Keepit-2.2.0.zip` on a macOS runner and attaches it to the
   GitHub Release for the tag (notes are generated from the commits).

`CFBundleShortVersionString` comes from `VERSION`; `CFBundleVersion` is the commit count
(`git rev-list --count HEAD`), so every build has a unique, increasing build number.

## Signing / notarization (optional, for distribution outside your own Macs)

The CI build is ad-hoc signed. Users who download it will see Gatekeeper's "unidentified
developer" warning and must right-click → Open once. To ship without that you need an
Apple Developer ID certificate and notarization:

1. Export the certificate as `.p12`, base64 it and store as repository secrets
   `MACOS_CERT_P12`, `MACOS_CERT_PASSWORD`, plus `APPLE_ID`, `APPLE_TEAM_ID`,
   `APPLE_APP_PASSWORD` (an app-specific password).
2. In the workflow, import the cert into a temporary keychain, build with
   `make dist SIGN_ID="Developer ID Application: Your Name (TEAMID)"`, then
   `xcrun notarytool submit Keepit-*.zip --apple-id … --team-id … --password … --wait`
   and `xcrun stapler staple Keepit.app`.

Because Accessibility permission is tied to the signature, a stable Developer ID also means
users grant the permission once and keep it across updates.
