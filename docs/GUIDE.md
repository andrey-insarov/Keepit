# Keepit user guide

Keepit is a clipboard history and template manager for macOS. It sits in the menu bar, remembers
what you copy, and pastes any of it back with a hot key. This guide walks through everything from
the first launch to automation. Keyboard shortcuts are given with the default settings; every one of
them can be changed in *Preferences → Hot keys*.

![The history menu](site/img/guide/menu.png)

## Contents

1. [Install](#1-install)
2. [First launch](#2-first-launch)
3. [The history menu](#3-the-history-menu)
4. [Paste without the menu](#4-paste-without-the-menu)
5. [The extended menu](#5-the-extended-menu)
6. [Templates](#6-templates)
7. [Placeholders — templates as a text expander](#7-placeholders--templates-as-a-text-expander)
8. [The Viewer](#8-the-viewer)
9. [Preferences](#9-preferences)
10. [Password, Touch ID and the recovery phrase](#10-password-touch-id-and-the-recovery-phrase)
11. [Backup and moving to another Mac](#11-backup-and-moving-to-another-mac)
12. [Automation: the keepit:// URL scheme](#12-automation-the-keepit-url-scheme)
13. [Updates](#13-updates)
14. [Uninstalling](#14-uninstalling)
15. [Troubleshooting](#15-troubleshooting)
16. [Cheat sheet](#16-cheat-sheet)

---

## 1. Install

**Homebrew** (recommended — updates with `brew upgrade`):

```bash
brew tap andrey-insarov/keepit https://github.com/andrey-insarov/Keepit
brew install --cask andrey-insarov/keepit/keepit
```

**DMG**: download `Keepit-<version>.dmg` from the
[latest release](https://github.com/andrey-insarov/Keepit/releases/latest), open it and drag Keepit
into *Applications*. The app is signed and notarized by Apple and updates itself.

![The DMG: drag Keepit to Applications](site/img/guide/dmg.png)

The first time you open it macOS confirms that the app came from the Internet and was checked by
Apple — click *Open*.

![macOS Gatekeeper confirmation](site/img/guide/gatekeeper.png)

Keepit needs macOS 13 Ventura or newer and runs natively on Apple silicon and Intel Macs.

## 2. First launch

Keepit is a menu-bar app: there is no Dock icon and no window until you ask for one. After the first
launch you will see the 📎 icon in the menu bar and two dialogs.

![Keepit asks for the Accessibility permission](site/img/guide/accessibility-prompt.png)

![Keepit enabled under Privacy & Security → Accessibility](site/img/guide/accessibility-settings.png)

**Accessibility permission.** To paste for you, Keepit sends ⌘V to the app you were working in. macOS
only allows that for apps listed under *System Settings → Privacy & Security → Accessibility*. Turn
Keepit on there. Without it everything still works, but after choosing an item you press ⌘V yourself.

**Password offer.** Keepit can keep your history and templates AES-256 encrypted. You can set a
password now or later in *Preferences → Security*; the same dialog offers Touch ID. See
[section 10](#10-password-touch-id-and-the-recovery-phrase) for how this works. You can skip it —
Keepit is fully usable without a password.

Keepit launches at login by default (you can turn that off on the *General* tab).

## 3. The history menu

Press **⌥C** in any app, or click the 📎 icon. The menu opens at your text cursor when Keepit can
find it, otherwise at the mouse pointer.

![History menu: numbered items, source app icons, ⌃⌥ keys](site/img/guide/menu.png)

Each line is one thing you copied, newest first; the newest one is **bold** — it is what is on the
clipboard right now. The icon on the left is the app you copied it from. A title that ends with `…`
has more lines than the menu shows.

**Choosing an item**

* Click it, or move to it with ↑/↓ and press Return. It is pasted into the app you came from.
* Press the number shown on the left — `1`…`9`, `0` — with **⌃⌥**: `⌃⌥3` pastes item 3. The same key
  works from anywhere, without opening the menu (see the next section).
* Images show a thumbnail instead of a title; files show their names.

![An image in the history: thumbnail in the menu, full picture in the preview](site/img/guide/menu-image.png)

**Searching.** Just start typing: the field at the top of the menu filters the list as you type —
by title and by the full text, so you can find a line in the middle of a long clip. Return pastes the
first match, Esc clears the field (press it again to close the menu).

![Typing filters the menu; the preview panel shows the highlighted item](site/img/guide/search-preview.png)

**Preview.** Hover over an item (or move to it with the keyboard) and a panel appears beside the
menu with the full image, or the first lines of a long text, plus the source app, date and size.
Short one-line texts have no preview — the menu line already shows them whole.

**Below the history** you find the *Template* submenu, the Viewer, Preferences, *Clear History*,
*Pause Recording for 10 Minutes* (for typing something you do not want recorded), *Lock Keepit*
(when a password is set) and the updater.

**⌥T** opens the template menu on its own.

## 4. Paste without the menu

For the things you do many times a day there are global hot keys that work from any app, without
opening the menu. They act on the history as it is at that moment — item 1 is the clipboard.

| Keys | What happens |
|------|--------------|
| `⌃⌥1` … `⌃⌥9`, `⌃⌥0` | Paste history item 1–10 |
| `⌥⇧V` | Paste the *previous* item (item 2). Pressing it again swaps back — handy for alternating between two clips |
| `⌃⌥V` | Paste the clipboard as plain text (formatting stripped) |
| `⌃⌥U` / `⌃⌥L` / `⌃⌥T` / `⌃⌥S` | Paste the clipboard as UPPERCASE / lowercase / Title Case / Sentence case |
| `⌃⌥W` | Paste the clipboard with leading and trailing whitespace trimmed |
| `⌃⌥J` | Paste the clipboard joined into a single line |
| `⌃⌥A` | Add the clipboard to Templates |
| `⌃⌥⌫` | Delete the newest item from the history |

The transformations work on text; for an image or a file list the key just beeps. Every combination
can be changed or switched off on the *Hot keys* tab.

## 5. The extended menu

Hold **⇧** while the history menu is open and every item gets a `▸` submenu with all actions for
that item: Paste, Paste as plain text, Copy only (put it on the clipboard without pasting), the
*Paste as* transformations, Add to Templates, Show in Viewer, Delete.

![Hold ⇧: every item gets a submenu; for the newest item it shows the global hot keys](site/img/guide/extended-menu.png)

![For other items the same actions, without shortcuts](site/img/guide/extended-menu-item2.png)

Point at an item (or press →) and the submenu opens beside the list; you can let go of ⇧ once it is
open. For the newest item the submenu also lists the global hot keys from the table above — they do
exactly the same thing, so you can learn them from here. Other items have no shortcuts in the
submenu: a key either works always or is not shown.

## 6. Templates

Templates are clips you keep permanently: signatures, addresses, canned replies, code snippets, an
image you paste often. They live in a tree with folders and show up in the *Template* submenu of the
history menu and under **⌥T**.

![The template menu: folders open as submenus, &-letters become shortcuts](site/img/guide/template-menu-letters.png)

**Adding a template**

* From the history menu: hold ⇧, open the item's submenu, *Add to Templates* — or press `⌃⌥A` for the
  newest item, or *Add Clipboard to Templates* at the bottom of the menu.
* In the Viewer: select a history item and click *Add to Template*, or drag it onto the Template
  tree. *New Item* creates an empty text template you type into; *New Item from File* (context menu)
  makes one from a text or image file.

**Organising.** In the Viewer, *New Folder* creates a folder; drag items between folders or use
*Up*/*Down*. A template whose name is `-` becomes a separator line in the menu. Put `&` before a letter
in the name — `&Signature` — and that letter becomes the item's shortcut in the template menu (press
`S` while the menu is open). *Set Hot Key* in the context menu gives a template its own global hot key
that pastes it from anywhere.

**Names.** A template without a name shows its first line. Rename with the *Name* field above the
editor, or *Rename* / *Clear Name* in the context menu.

## 7. Placeholders — templates as a text expander

Text templates can contain `{…}` placeholders that are filled in when the template is pasted. Put
them anywhere in the text; everything without braces is pasted unchanged. The **?** button at the
right end of the Viewer's toolbar opens a reference of all of them.

<!-- screenshot: the Placeholders & Automation window (? button in the Viewer) -->

| Placeholder | Result |
|-------------|--------|
| `{date}` `{time}` `{datetime}` | Today's date / current time in the system format |
| `{date:yyyy-MM-dd}` `{time:HH:mm}` | Any format (Unicode date patterns: `yyyy MM dd EEEE HH mm …`) |
| `{date+7d}` `{date-1m:MMMM}` | Shifted date: `d` days, `w` weeks, `m` months, `y` years, `h` hours |
| `{weekday}` `{month}` `{year}` `{iso}` `{unix}` | Day name, month name, year, ISO 8601 timestamp, Unix time |
| `{clipboard}` `{clipboard:2}` | The clipboard (history item 1) or item N |
| `{clipboard\|upper}` `{clipboard:2\|trim\|oneline}` | Filters: `upper` `lower` `title` `trim` `oneline` `url`, chainable |
| `{input:Name}` `{input:Name=Default}` | Asks for a value in a dialog before pasting; the same name is asked once |
| `{choice:Tone=warm\|formal}` | Asks to pick one of the options |
| `{cursor}` | Where the text cursor ends up after pasting |
| `{user}` `{username}` `{host}` | Full name, account name, computer name |
| `{uuid}` `{random:1-100}` | A new UUID; a random number in the range |
| `{{` `}}` | Literal braces |

Example — a reply template:

```
Hi {input:Name},

thanks for your message of {date-1d}. I'll get back to you by {date+3d:EEEE}.
{cursor}
{user}
```

Pasting it opens a small dialog asking for *Name*, inserts the dates, puts your full name at the end
and leaves the cursor on the empty line.

<!-- screenshot: the input dialog of a template with {input:} -->

## 8. The Viewer

*Viewer…* in the menu (or right-click the 📎 icon) opens a window with three trees: **Clipboard**
(what is on the clipboard now, read-only), **History** (split into *Text & files* and *Images*) and
**Template**.

![The Viewer with a template selected](site/img/guide/viewer.png)

![Searching in the Viewer highlights matches](site/img/guide/viewer-search.png)

* Select an item to see it on the right: text is editable in place (changes apply when you leave the
  editor), images are shown, file lists open the file on double-click. *Binary* toggles a hex dump of
  the raw data.
* The status bar shows the date, source app, format and size.
* **Search** (`⌘F`): the field in the toolbar filters history and templates by name and content and
  highlights the match in yellow.
* *Send to Clipboard* puts the item on the clipboard; *Paste* also pastes it into the app you were in.
* Drag history items into the Template tree to keep them; drag templates into History to copy them
  back; reorder with drag or *Up*/*Down*. ⌫ deletes the selected item.

## 9. Preferences

`⌘,` from the menu, or *Preferences…*. Every option with a **?** next to it has a popover explaining
it — click the button.

![Preferences → Hot keys](site/img/guide/prefs-hotkeys.png)

**General** — launch at login; save the history on quit and restore it on start; paste after
choosing (off = only put on the clipboard); the delay before ⌘V is sent (raise it for apps that
need a moment to come to the front); open the menu at the text cursor.

**Hot keys** — every global shortcut in one place: the two menus, *Paste previous item*, *Paste item
by number* (the modifiers that go with 1–0), *Actions on the latest item* (the modifiers that go with
V/U/L/T/S/W/J/A/⌫), and optional keys for *Lock Keepit* and *Pause / resume recording*. Click a field
and press the combination; ⌫ switches a key off; *Reset to Defaults* restores ⌥C, ⌥T, ⌥⇧V and ⌃⌥.
Two of your own keys on the same combination are refused on Save. If macOS or another app already
owns a combination, Keepit tells you when it starts.

**History** — how many text/file items and images to keep (1000 and 30 by default), an optional age
limit, *Remove duplicates* (copying the same thing again moves it to the top instead of adding a
second copy), *Ignore concealed clipboard data* (password managers mark their copies as concealed),
and the list of ignored apps by bundle identifier. Known password managers are always ignored.

**Menu** — the search field, numbering, the preview panel, tooltips, source-app icons, image
thumbnails, title length and thumbnail height.

**Security** — see the next section — and *Export / Import Backup*.

![Preferences → Security](site/img/guide/prefs-security.png)

**Advanced** — clipboard poll interval, *Open Data Folder*, and the Danger zone: *Delete Keepit and
All Data…* removes the app with everything it stored (see [Uninstalling](#14-uninstalling)).

## 10. Password, Touch ID and the recovery phrase

Turn on *Require password at launch* and Keepit encrypts the history and templates with AES-256-GCM.
The key is derived from your password (PBKDF2, 200 000 rounds) and lives only in memory; it is wiped
when Keepit locks — on demand (*Lock Keepit*, `⌘L` in the menu), when the screen locks or the Mac
sleeps (optional), and on quit.

![The password offer on first launch](site/img/guide/password-offer.png)

![Setting the password: layout indicator and strength meter](site/img/guide/set-password.png)

![The 24-word recovery phrase (words hidden here)](site/img/guide/recovery-phrase.png)

![Unlocking with Touch ID; the password stays as fallback](site/img/guide/touch-id.png)

**Touch ID.** With *Unlock with Touch ID* on, the key is additionally stored in the Secure Enclave
behind your fingerprint: Keepit asks for a touch instead of the password. The password always keeps
working as a fallback (the *Use Password* button). On a Mac with the lid closed and an external Magic
Keyboard with Touch ID, Keepit asks on the keyboard. *Allow changing the password with Touch ID* lets
a fingerprint stand in for the old password when you change it.

**Recovery phrase.** When you set a password Keepit shows a 24-word phrase once — print it or store it
in a password manager. If you forget the password, *Use Recovery Phrase…* on the unlock dialog opens
the data and lets you set a new password. *New Recovery Phrase…* issues a new one and invalidates the
old. Without the password, Touch ID on the same Mac, or the phrase, the data cannot be recovered —
there is no server and nothing to reset.

The unlock dialog shows the current keyboard layout and a Caps Lock warning so a wrong password is
less of a mystery.

## 11. Backup and moving to another Mac

*Preferences → Security → Export Backup…* writes one `.keepit` file with the history, templates and
preferences, encrypted with a password you choose for the file. *Import Backup…* on the other Mac
reads it back — *Merge* adds to what is there, *Replace* starts from the backup. The same file moves
data between the direct download and the App Store edition.

## 12. Automation: the keepit:// URL scheme

Shortcuts, Raycast, Alfred, Keyboard Maestro or a shell `open` can drive Keepit through URLs
(the **?** button in the Viewer lists them in the app):

| URL | Effect |
|-----|--------|
| `keepit://paste/2`, `keepit://paste/latest`, `keepit://paste/previous` | Paste history item N into the front app |
| `keepit://copy/3` | Put item N on the clipboard without pasting |
| `keepit://template/Signature`, `keepit://template/Work/Reply?copy=1` | Paste (or copy) a template by name or folder path |
| `keepit://add?text=…` | Add text to the history and the clipboard |
| `keepit://add-template?text=…&name=…` | Create a template |
| `keepit://history`, `keepit://templates`, `keepit://viewer`, `keepit://preferences` | Open the menus and windows |
| `keepit://pause`, `keepit://resume` | Pause recording for 10 minutes / resume |

In Shortcuts use the *Open URL* action. Percent-encode the text (`%20` for a space). URLs are
ignored while Keepit is locked.

## 13. Updates

Keepit checks GitHub Releases once a day and offers updates in a dialog; *Check for Updates…* does it
now. Updates are signed (EdDSA) and notarized. With Homebrew, `brew upgrade --cask keepit` does the
same. Checksums for every download are in `SHA256SUMS` on the release page.

## 14. Uninstalling

*Preferences → Advanced → Delete Keepit and All Data…* removes the app bundle, the data folder, the
keychain entries (including the Touch ID key), the login item and the Accessibility entry. It asks
for your password or Touch ID, a typed `DELETE` and a confirmation checkbox — export a backup first
if you might want the data back. With Homebrew, run `brew uninstall --cask --force keepit` afterwards
so Homebrew forgets the cask too.

## 15. Troubleshooting

**Nothing is pasted after choosing an item.** Accessibility is missing: *System Settings → Privacy &
Security → Accessibility → Keepit*. If Keepit is listed but still does not paste, turn it off and on
again — macOS forgets the grant when the app is rebuilt or reinstalled.

**A hot key does nothing.** Another app or macOS owns it; Keepit says so at launch. Pick a different
combination on the *Hot keys* tab. ⌃⌥ with digits and letters is free on a stock Mac.

**The menu opens in the wrong place.** The app you are in does not expose its text cursor; the menu
falls back to the mouse pointer. Turn *Open menu at text cursor* off if you prefer the pointer always.

**Something I copied is missing.** Copies from password managers and anything marked concealed are
never recorded, and apps in the ignore list are skipped. Check *History → Ignored apps*.

**Touch ID is not offered.** The Mac has no Touch ID sensor reachable at the moment (lid closed and no
Touch ID keyboard). Keepit keeps the setting and asks for the fingerprint again as soon as a sensor
is available.

**Homebrew refuses to install over an existing app.** Quit Keepit and move `/Applications/Keepit.app`
to the Trash first, or add `--force`.

More: [GitHub Issues](https://github.com/andrey-insarov/Keepit/issues) · dp@intistele.com

## 16. Cheat sheet

| Keys | Action |
|------|--------|
| `⌥C` | History menu (type to search) |
| `⌥T` | Template menu |
| `1`–`9`, `0` in the menu, or `⌃⌥1`–`⌃⌥0` anywhere | Paste item 1–10 |
| `⇧` in the menu | Extended menu with all actions per item |
| `⌥⇧V` | Paste the previous item / swap |
| `⌃⌥V` | Paste the clipboard as plain text |
| `⌃⌥U` `⌃⌥L` `⌃⌥T` `⌃⌥S` | UPPERCASE / lowercase / Title Case / Sentence case |
| `⌃⌥W` `⌃⌥J` | Trimmed / single line |
| `⌃⌥A` | Add the clipboard to Templates |
| `⌃⌥⌫` | Delete the newest item |
| `⌘L` in the menu | Lock Keepit |
| `⌘F` in the Viewer | Search |
| `⌘,` | Preferences |
