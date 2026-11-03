# Privacy Policy — Keepit – Clipboard Manager

*Version 1.4, effective 3 November 2026.*

**In short: Keepit does not collect, transmit, sell or share any personal data. Everything the app stores stays on your Mac, under your control — and if you choose to back it up to a folder of yours, the copies are encrypted and go only where you point them (section 2).**

## 1. Who we are

Keepit – Clipboard Manager ("Keepit", "the app") is published by **UK Intis Telecom LTD**, a company registered in England and Wales under company number **11767499**, registered office **20 Hammersmith Broadway, London, England, W6 7AF** ("we", "us"). We are the data controller for the purposes of the UK GDPR and the EU GDPR to the extent any personal data is processed in connection with Keepit — which, as explained below, we do not do.

Privacy contact: **admin@keep.it.com**

## 2. What Keepit does with your data

Keepit records what you copy to the macOS clipboard — text, images and file references — so that you can paste it again later, and stores the templates you create. This content may contain personal data (yours or other people's), depending on what you copy.

All of it is stored **only on your computer**, in `~/Library/Application Support/Keepit/` (App Store edition: inside the app's sandbox container, `~/Library/Containers/com.it.keep/`). It is never uploaded to us or to anyone else, and we have no access to it. You can delete it at any time from the Viewer, with *Clear History*, or by removing the folder.

**Backups you choose to make.** If you switch on automatic backup (*Settings → General → Backup*) or use *Export…*, Keepit writes encrypted copies of the history, templates and preferences into a folder *you* select. If that folder is synced by a cloud service (iCloud Drive, Dropbox, Google Drive, …), the files go to that service under *your* account and *its* privacy policy — not to us; Keepit has no server and never receives them. The content is AES-256-GCM encrypted and unreadable without your Keepit password or recovery phrase (or, for exported files, the password you chose). What the service — or anyone who gets hold of the file — can see is the file's size and its unencrypted header: that it is a Keepit backup, when it was written and by which Keepit version, the key-derivation parameters and salt, random identifiers for the installation and the file, the vault's recovery block (your data key wrapped under the recovery phrase; useless without the phrase) and, only if you enable the option, your Mac's name. The [security page](security.html#backups) lists the header field by field. Automatic backup is off by default. Deleting a file from the folder removes it there; copies the service keeps as versions, or that were downloaded elsewhere, are outside Keepit's reach.

## 3. What Keepit does not do

- No account, sign-up or login.
- No analytics, telemetry, crash reporting, advertising or tracking of any kind.
- No third-party SDKs that collect data.
- No network connections, with the single exception described in section 6 — and that one can be switched off.
- No background reading of other applications' content: Keepit only observes the system clipboard, which applications write to deliberately when you copy.

## 4. Security of locally stored data

If you enable password protection, history and templates are stored encrypted with AES-256-GCM using a key derived from your password (PBKDF2-HMAC-SHA256, 200 000 rounds, random salt). The password is never stored. The key is wiped from memory when Keepit locks (manually, when the screen locks, or when the Mac sleeps).

Optional Touch ID unlock keeps a copy of that key in the macOS keychain, protected by the Secure Enclave and bound to your current fingerprints. The optional 24-word recovery phrase is generated and displayed on your Mac once; Keepit does not store it and we never see it. **If you lose both the password and the recovery phrase, the encrypted data cannot be recovered by anyone, including us.**

## 5. Password managers and concealed content

Keepit does not record clipboard content marked as concealed or transient by the copying application. It also skips copies made while a known password manager (1Password, Bitwarden, KeePassXC, Keychain Access, Apple Passwords and others) or an application on your ignore list was in front; because macOS does not tell applications which program wrote the clipboard, this second rule is best effort — the [security page](security.html#what-is-not-recorded) explains its limits. You can add any application to the ignore list in Settings → History.

## 6. Network connections and third parties

- **Updates (direct-download edition only).** The edition downloaded from keep.it.com / GitHub checks for new versions by downloading a small file (`appcast.xml`) from GitHub Releases, by default once a day and whenever you choose *Check for Updates…*. You can turn the check off (Settings → General → Updates); Keepit then makes no network request at all. The request carries no personal data, but, like any HTTPS request, exposes your IP address and user agent to GitHub, Inc., whose [privacy statement](https://docs.github.com/site-policy/privacy-policies/github-general-privacy-statement) applies. Downloads of the app itself come from GitHub as well.
- **Mac App Store edition.** Contains no update checker at all. Installation and updates are handled by Apple; Apple's [privacy policy](https://www.apple.com/legal/privacy/) governs that process. We receive only Apple's aggregated, anonymised download statistics.
- **This website (keep.it.com).** Static pages served through Cloudflare, Inc. Cloudflare may process connection metadata (IP address, request headers) to deliver and protect the site; see Cloudflare's [privacy policy](https://www.cloudflare.com/privacypolicy/). We do not set cookies and do not run analytics on the site.
- **The support form (keep.it.com/support).** If you write to us through the form, the name, e-mail address, message and screenshots you enter are e-mailed to us and used only to answer you; they are not stored on the website. The form is protected against bots by Cloudflare Turnstile, which may process connection metadata under Cloudflare's policy, and the e-mail is delivered through Resend, Inc. ([privacy policy](https://resend.com/legal/privacy-policy)). We keep the correspondence as long as needed to resolve your request. Legal basis: our legitimate interest in answering support requests (Art. 6(1)(f) GDPR).

No other third parties are involved. We do not sell, rent or share personal data.

## 7. Legal basis

Because Keepit processes your clipboard content only on your device and we never receive it, we do not process your personal data in the sense of the UK GDPR / EU GDPR in the course of providing the app. Where incidental connection metadata reaches GitHub, Apple or Cloudflare as described in section 6, those providers act under their own policies; our interest is the legitimate interest of distributing and updating the software (Art. 6(1)(f) GDPR).

## 8. Your rights

Under the UK GDPR / EU GDPR you have rights of access, rectification, erasure, restriction, portability and objection, and the right to complain to a supervisory authority (in the UK, the Information Commissioner's Office, ico.org.uk). Since we hold no personal data about Keepit users, there is in practice nothing for us to access, correct or erase — the data is on your Mac and you control it directly. If you contact us by email, we keep that correspondence only as long as needed to answer you.

## 9. Children

Keepit is a general-purpose utility, not directed at children under 13 (16 in some jurisdictions), and we do not knowingly collect data from children — or from anyone.

## 10. International transfers

We do not transfer your data anywhere, because we do not receive it. GitHub, Apple and Cloudflare may process connection metadata in the United States and elsewhere under their own safeguards.

## 11. Changes to this policy

We may update this policy when the app or the law changes. The current version is always at <https://keep.it.com/privacy.html>, with its version number and effective date at the top; material changes will also be noted in the app's release notes.

## 12. Contact

UK Intis Telecom LTD · 20 Hammersmith Broadway, London, England, W6 7AF · **admin@keep.it.com** · <https://keep.it.com>
