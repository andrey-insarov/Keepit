# Origins

Keepit started in 2026 as a macOS take on the workflow of [CLCL](https://github.com/nakkag/CLCL),
Ohno Tomoaki's Windows clipboard tool: a tray icon, a popup at the text cursor, numbered items,
a template tree. Nothing of CLCL's C code was used — Keepit was written from scratch in Swift —
but the first versions mirrored CLCL's behaviour closely, and this file keeps that map for the
record. Since then the app has been rewritten and extended well beyond it (paste queue, placeholders,
AES-256 vault with Touch ID and a recovery phrase, Settings the Mac way, 21 languages, backups,
a URL scheme), with ideas borrowed from many clipboard and snippet managers on every platform.
Keepit is not affiliated with or endorsed by the CLCL author.

## What CLCL had and what Keepit did with it

| CLCL (Windows)                               | Keepit (macOS)                                            |
|----------------------------------------------|------------------------------------------------------------|
| Tray icon, left click = menu, right = viewer | Menu-bar icon 📎, left click = history menu, right click = Viewer |
| `Alt+C` history+template popup, pastes       | `⌥M` (configurable), pops at the text cursor, pastes with `⌘V` |
| `Alt+T` template popup                       | `⌥T` (configurable)                                        |
| Numbered menu items `&1 … &9 &0 &A …`        | Items are numbered; `⌃⌥1 … ⌃⌥0` paste item 1–10 — inside the menu and from any app (configurable; menu-only `1-9/0/A-Z` when the global keys are off) |
| —                                            | Search field at the top of the history menu: typing filters in place, Return pastes the first match |
| —                                            | Extended menu: hold `⇧` and every item gets a submenu — paste as plain text, UPPERCASE / lowercase / Title Case / Sentence case / trimmed / single line, copy only, add to Templates, show in Viewer, delete |
| —                                            | **Paste queue**: `⌥N` starts it, every ⌘C adds to a counter in the menu bar, `⌥V` pastes the items back one by one in the same order, `⌥⇧N` pastes all that is left; ends by itself after the last item or an idle timeout |
| —                                            | Global hot keys on the latest item (the clipboard): `⌃⌥V` plain text, `⌃⌥U/L/T/S/W/J` transformations, `⌃⌥A` add to Templates, `⌃⌥⌫` delete; `⌥⇧V` pastes the previous item (swap); `⌥E` Viewer, `⌥S` Settings, `⌥C` Clear History, `⌥P` pause, `⌥L` lock, `⌥Q` quit. All of them on the *Shortcuts* pane of Preferences |
| Bitmap thumbnails and tooltips in the menu   | Same (PNG thumbnails, text tooltips) plus a preview panel next to the highlighted item and the source app's icon |
| Formats: TEXT, UNICODE, RTF, HTML, BITMAP, HDROP | plain text, RTF, HTML, PNG (TIFF converted), file URLs |
| History max (30), overlap check, save/restore| Separate rings: 1000 text/file items + 30 images by default, JSON in `~/Library/Application Support/Keepit/` |
| Window filter (ignore apps)                  | Built-in list of password managers (always ignored) + user ignore list + `org.nspasteboard.ConcealedType` |
| Per-window paste key (`sendkey`)             | Per-bundle-id paste key in `settings.json` (`pasteKeys`)   |
| Templates (hierarchical "Regist")            | Same: folders, any format (text/image/files), `-` separators, `&x` shortcuts, per-item hot key, `{date}`/`{clipboard}`/`{input:…}`/`{cursor}` placeholders |
| Automation                                   | `keepit://` URL scheme: `paste/N`, `copy/N`, `template/Name`, `add?text=`, `add-template?text=&name=`, `history`, `templates`, `viewer`, `settings`, `pause`, `resume` — use from Shortcuts (“Open URL”), Raycast, Alfred or `open` |
| Viewer: tree Clipboard / History / Template  | Same tree, with a search field (`⌘F`) that filters history and templates and highlights matches |
| Viewer: edit text, bitmap view, file list, binary view | Text/RTF/HTML editing (applied when focus leaves), image view, file list (double-click opens), hex dump toggle |
| Viewer context menu                          | Send to Clipboard, Paste, Add to Template, New Item/Folder, New Item from File, Rename, Clear Name, Set Hot Key, Save Format to File, Up/Down, Delete |
| Viewer drag & drop                           | History → Template (copy), Template → History (copy), reorder within each |
| Status bar                                   | Date, source app, format, size, hot key                    |
| Options dialog (CLCLSet)                     | Settings window with panes General / Shortcuts / Paste Queue / History / Menu / Security / Advanced, hot-key recorders, (?) help popovers |
| —                                            | Export / Import Backup: one password-encrypted `.keepit` file (history, templates, preferences); Merge or Replace on import |
| —                                            | 21 interface languages: en, ru, uk, de, fr, es, it, pt-BR, nl, pl, cs, tr, lt, lv, et, ja, ko, zh-Hans, zh-Hant, ar, he |

Still not ported: plugins/tools, format filter/priority option pages, importing Windows
`history.dat` / `regist.dat`, the `%0d`-style menu numbering format.


## Where CLCL's source files ended up (historical)

```
Sources/Keepit/
  main.swift                   WinMain → NSApplication
  AppDelegate.swift            main.c: tray icon, hot-key dispatch, popup menus, actions
  Models/
    ClipItem.swift             Data.c / Format.c / fmt_*.c: one history entry with its formats
    TemplateNode.swift         Regist.c tree node
    Settings.swift             Ini.c option struct (JSON instead of ini)
  Core/
    ClipboardMonitor.swift     ClipBoard.c: WM_CLIPBOARDUPDATE → NSPasteboard.changeCount polling
    HistoryStore.swift         History.c
    TemplateStore.swift        Regist.c persistence
    HotKeyManager.swift        RegisterHotKey → Carbon RegisterEventHotKey
    Paster.swift               SendKey.c (keybd_event) → CGEvent; caret lookup via Accessibility API
    Storage.swift              File.c / Profile.c: JSON files in Application Support
    Vault.swift                password prompt, PBKDF2 → AES-GCM for the data files
  UI/
    MenuBuilder.swift          Menu.c: owner-drawn menu → NSMenu with images, key equivalents, tooltips
    HotKeyRecorderView.swift   SetHotkey.c
    SettingsWindow.swift    CLCLSet (subset)
    ViewerWindow.swift         Viewer.c / TreeView.c / ListView.c: tree + actions + drag & drop
    FormatViews.swift          fmt_text_view.c / fmt_bitmap_view.c / fmt_file_view.c / BinView.c
```

