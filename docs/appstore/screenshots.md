# Screenshots for the Mac App Store

Accepted sizes: 1280×800, 1440×900, 2560×1600, 2880×1800 (16:10). 1–10 images, first one matters most.

Planned set (capture at 2560×1600 on a Retina display, or 1280×800 logical):

1. Popup history menu over a text editor, caret visible — "Paste anything you copied with ⌥C"
2. Template menu with folders and shortcut letters — "Templates with their own hot keys"
3. Viewer: tree + text being edited — "Browse and edit everything"
4. Viewer: image item — "Images and files too"
5. Preferences: password / Touch ID / recovery section — "Encrypted and locked with Touch ID"
6. Recovery phrase dialog (with dummy words) — "A recovery phrase in case you forget"

Raw captures go to `docs/appstore/raw/`; `make store-screenshots` (Playwright, run in the dev
container) frames them on a gradient background with the caption and writes 2560×1600 PNGs to
`docs/appstore/out/`.
