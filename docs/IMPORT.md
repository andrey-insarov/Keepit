# Import from other clipboard and snippet managers (3.1)

Status: design draft for review, 5 Nov 2026. Nothing here is built yet. Facts marked **[source]**
were read in the other program's source code or official documentation; facts marked
**[fixture]** are to be confirmed on real files that Andrey produces from an installed copy before
the parser is written. A format with neither mark is not imported until it has both.

## Why and what

People who try Keepit already have a history and a snippet collection somewhere else. The import
brings those in **once**, into the same stores the app uses, so nothing has to be retyped and the
old app can be removed. It is not a sync and it is not a backup: *Settings → Backup → Restore* reads
`.keepit` files; *Settings → Import* reads other programs' files. The two flows share the commit
machinery (see "How it is applied") and nothing else — different wording, different pane, different
guide chapter.

Only **open, documented or readable** formats. Paste, Pastebot and PastePal keep their data in
CloudKit-backed stores with no export; they are not imported and the pane does not list them.

What is taken, in one sentence per kind:

- **History** → history items: text, RTF/HTML where present, images, file references, with the
  original copy date and source app; pinned/favourite items become pinned in Keepit where a pin
  concept exists on both sides, otherwise plain items.
- **Snippets** → templates: one folder per imported program, the program's own folders beneath
  it, text with placeholders converted to Keepit's `{…}` where the meaning maps 1:1 and **left as
  the original text where it does not** — never silently dropped, never guessed.

## Sources

### Wave 1 — ships in 3.1

| Program | What | Where (macOS) | Format |
|---|---|---|---|
| **Maccy** 2.x | history | `~/Library/Containers/org.p0deje.Maccy/Data/Library/Application Support/Maccy/Storage.sqlite` (+ `-wal`, `-shm`) — sandboxed app, `URL.applicationSupportDirectory.appending("Maccy/Storage.sqlite")` **[source]** | SwiftData/SQLite. `ZHISTORYITEM` (`ZTITLE`, `ZAPPLICATION`, `ZFIRSTCOPIEDAT`, `ZLASTCOPIEDAT`, `ZNUMBEROFCOPIES`, `ZPIN`) → `ZHISTORYITEMCONTENT` (`ZTYPE` = raw pasteboard type string such as `public.utf8-plain-text`, `public.png`, `public.tiff`, `public.rtf`, `public.html`, `public.file-url`; `ZVALUE` = BLOB; `ZITEM` → item) **[source: Models/HistoryItem.swift, HistoryItemContent.swift]**. Column names, Core Data epoch for dates, file-URL encoding **[fixture]** |
| **Alfred** 4/5 (Powerpack) | history | `~/Library/Application Support/Alfred/Databases/clipboard.alfdb` (Preferences → Advanced → *Reveal in Finder* → Databases) | SQLite: `clipboard(item, ts decimal, app, apppath, dataType integer, dataHash)`; `dataType` 0 text, 1 image, 2 file; image bytes live next to the database, addressed by `dataHash` **[source: schema as published by users; Alfred is closed]**. Epoch of `ts`, image file layout, what `item` holds for files **[fixture]** |
| **Alfred** | snippets | `.alfredsnippets` export (Features → Snippets → collection → Export) | zip of `info.plist` (collection name, prefix/suffix) + one `<uid>.json` per snippet: `{"alfredsnippet":{"snippet","uid","name","keyword"}}` **[fixture]** |
| **Raycast** | snippets | *Snippets → ⌘K → Export Snippets* → JSON | array of `{"name","text","keyword"}` **[fixture]**. Raycast's own clipboard history is not an open format — not imported |
| **Flycut** | history | `~/Library/Preferences/com.generalarcade.flycut.plist` (App Store build: `~/Library/Containers/com.generalarcade.flycut/…`) | `NSUserDefaults` key `store` → `jcList` and `favoritesList`, each an array of `{Contents, Type, AppLocalizedName, AppBundleURL, Timestamp}`; text only **[source: FlycutOperator.m loadEngineFrom:key:into:, saveStore:toKey:onDict:]**. `Type` values, `Timestamp` epoch **[fixture]** |
| **Espanso** | snippets | `~/Library/Application Support/espanso/match/*.yml` (every file in `match/`, recursively) | YAML `matches:` list — `trigger` / `triggers`, `replace`, `label`, `vars: [{name, type, params}]` referenced as `{{name}}`; `form:` with `[[field]]` **[source: espanso.org/docs/matches]**. Which extension types appear in real files **[fixture]** |

### Wave 2 — after wave 1 is accepted

| Program | What | Format notes |
|---|---|---|
| **Clipy / ClipMenu** | snippets | XML export: `<folders><folder><title/><snippets><snippet><title/><content/></snippet>…</snippets></folder>…</folders>`, one folder level, no placeholders **[source: CPYSnippetsEditorWindowController.swift]** |
| **TextExpander** | snippets | export file **[fixture]**; placeholders `%clipboard`, `%|` (cursor), `%Y %m %d %H %M` (strftime-style), `%fill:name%`, `%filltext:name=…:default=…%`, `%fillpopup:name=…:default=a:b%`, `%snippet:abbr%`, `%key:…%` |
| **aText** | snippets | export file **[fixture]**; TextExpander-compatible `%…%` placeholders |
| **CLCL** (Windows) | history + templates | `history.dat`, `regist.dat` — binary; parser written from the C source (nakkag/CLCL), fixture from Andrey's Windows copy |

## Placeholder conversion

Converted where the meaning is the same on both sides. Anything else stays as the original text,
and the item is counted under "needs attention" in the result (the Viewer can then show them with
a search for the original program's syntax).

| Meaning | Alfred | Raycast | Espanso | TextExpander/aText | Keepit |
|---|---|---|---|---|---|
| clipboard | `{clipboard}`, `{clipboard:0}` | `{clipboard}` | var `type: clipboard` | `%clipboard` | `{clipboard}` |
| clipboard, older item N | `{clipboard:N}` | `{clipboard offset=N}` | — | — | `{clipboard:N+1}` (Keepit counts from 1 = current) |
| cursor | `{cursor}` | `{cursor}` | `$|$` | `%|` | `{cursor}` |
| date, system format | `{date}` `{time}` `{datetime}` | `{date}` `{time}` `{datetime}` | var `type: date` without `format` | — | `{date}` `{time}` `{datetime}` |
| date, custom format | `{date:EEEE}` (Unicode pattern after the colon) | `{date format="yyyy-MM-dd"}` | `params.format` (strftime `%Y-%m-%d`) → converted to Unicode patterns | strftime `%Y-%m-%d` → converted | `{date:yyyy-MM-dd}` |
| date offset | `{date +7d}` units `Y M D h m s` | `{date offset="+2y +5M"}` | `params.offset` (seconds) | `%@+1D%…` | `{date+7d}` units `d w m y h` — `s`, `D`/`h`/`m` mapped; seconds dropped with "attention" |
| named `short/medium/long/full` | `{date:long}` | — | — | — | nearest explicit pattern (`dd MMM yyyy` etc.) — documented table |
| weekday | — | `{day}` | — | `%A` | `{weekday}` |
| ask for text | — | `{argument name="x" default="y"}` | form field `[[x]]` / `vars type: form` | `%fill:x%` `%filltext:name=x:default=y%` | `{input:x=y}` |
| ask to pick | — | `{argument name="x" options="a, b"}` | form field `type: choice` | `%fillpopup:name=x:default=a:b%` | `{choice:x=a\|b}` |
| UUID | `{random:UUID}` | `{uuid}` | var `type: random` (no) | — | `{uuid}` |
| random number | `{random:1..5}` | — | — | — | `{random:1-5}` |
| nested snippet | `{snippet:kw}` | `{snippet name="…"}` | var `type: match` | `%snippet:abbr%` | inlined at import when the target is in the same import; otherwise left as text |
| text filters | `.uppercase .lowercase .trim` | `\| uppercase \| lowercase \| trim` | — | — | `\|upper \|lower \|trim` |
| not representable | `{query}`, `{var:…}`, `{random:a,b}` (word list) | `{selection}`, `{calculator}`, `{browser-tab}` | `shell`, `script`, `echo` (global vars inlined if literal) | `%key:…%`, `%snippet:…%` to a missing snippet | left as text, counted |
| literal braces in source text | — | — | — | — | `{` `}` in imported plain text → `{{` `}}` so Keepit does not read them as placeholders |

Keyword/trigger/abbreviation: Keepit templates have no trigger expansion; the keyword is kept in the
template name as `Name (keyword)` only when the program has no separate name (Espanso `trigger`
without `label`), otherwise dropped. Hot keys are never assigned to imported templates (same rule as
Restore → Merge).

## How it is applied

1. **Detect.** On opening the pane, each importer's `detect()` looks for its file at the known
   paths (read-only, no app launched) and reports *name, item count, newest item date* or
   "not found". Sandboxed Keepit (App Store build) cannot read other containers: there the row says
   *Choose file…* and the open panel is pre-pointed at the path. **Nothing is read before the user
   clicks Import.**
2. **Read** (`KeepitCore/Importers`, no AppKit): file → `ImportPayload { history: [ClipItem],
   templates: TemplateNode, notes: [Note] }`. The reader never writes to the source file; SQLite is
   opened read-only on a **copy** of the database plus its `-wal`/`-shm` (a live WAL must not be
   opened by a second writer — and `mode=ro` on the original can still fail while the other app
   runs). Every limit applies while reading: `Limits.textBytesCeiling`, image count, template depth
   and count — a source over the limits is reported before anything is committed, like Restore does.
3. **Preview.** The same sheet style as Restore's preview: *N history items (M duplicates of what
   you already have), K templates in folder "Imported from Maccy, 5 Nov 2026", J items need
   attention*; checkboxes *History* / *Templates*; the list of "attention" items with the
   placeholder that was left as text.
4. **Commit** through `RestorePlan` in Merge mode and `RestoreCommit.writeFiles`: fresh ids,
   history deduplicated by `contentHash` against existing items (an imported duplicate updates
   nothing — the existing item wins, its date is kept), templates in one new folder without hot
   keys, count/depth checked, monitor paused, journal, settings untouched. No rollback copy is
   written (Merge adds, it does not replace) — same as Restore → Merge today.
5. **Result** alert: imported / skipped as duplicates / needs attention; the Viewer opens on the
   new folder when templates were imported.

Pinned items: Maccy `ZPIN`, Flycut `favoritesList`, CLCL fixed entries → Keepit pinned. Alfred has
no pins. Source app (`application`, `app`/`apppath`, `AppBundleURL`) → `sourceApp`. Copy dates →
`date` (first copy); items keep their source order when dates tie.

## What is not done

- No live sync, no repeated import that "catches up" — a second import of the same source adds
  only what is new by content hash, which is good enough.
- No import of the other program's settings, hot keys, exclusion lists or ignore rules.
- No writing back to the other program. Export in the other direction is a separate item (Espanso
  YAML export of templates, 3.1 roadmap).
- Closed stores (Paste, Pastebot, PastePal, Raycast history, Alfred's image blobs if their layout
  turns out undocumented after the fixture) — listed under "not supported" in the guide, not in the
  pane.

## Settings → Import (pane)

After *Backup*, before *Advanced*. One group **From another app on this Mac**: one row per wave-1
program — icon, name, status (*1 240 items, newest 3 Nov* / *Not found* / *Choose file…*) and an
*Import…* button; below, **From a file**: *Choose file…* with the file types of every importer. The
(?) explains what is taken and what is not. Same grammar as the other panes (header per group, one
row per line, help only behind (?), one control width).

## Stages and the audit

0. This document → draft PR, auditor's review of scope, mapping table and the commit path.
1. `KeepitCore/Importers`: `Importer` protocol, `Maccy`, `Alfred` (history), `Flycut`, `Espanso`,
   `AlfredSnippets`, `Raycast` readers; fixtures in `Tests/Fixtures/import/<program>/` made by
   Andrey from installed copies (nothing real inside); one test per reader per fixture; placeholder
   conversion as a pure function with its own table-driven tests.
2. Commit path: `ImportPayload` → `RestorePlan(.merge)`; tests for dedup, folder naming, limits,
   journal interruption (reuse RestorePlanTests' harness).
3. Pane + preview + result; guide chapter *Importing from other apps*; screenshots; CHANGELOG.
4. Wave 2 readers (Clipy, TextExpander, aText, CLCL), each its own PR.

Each stage: draft PR, auditor's findings become tests, next stage only after "no further findings".

## Fixture checklist (Andrey)

In each history manager copy the same set: three texts (one multi-line, one with non-Latin and an
emoji), a URL, an image, a file from the Finder, an RTF fragment; pin one item where the program
can. In each snippet manager: a plain snippet, one with date + clipboard + cursor, one with an input
field (where supported), inside one folder/group. Then:

- Maccy: quit Maccy, zip the `Maccy/` folder (sqlite + wal + shm).
- Alfred: `clipboard.alfdb` (+ `-wal`) and the `.alfredsnippets` export of the test collection.
- Raycast: the exported JSON.
- Flycut: quit Flycut, `com.generalarcade.flycut.plist`.
- Espanso: the `match/` folder.
- Wave 2 when at hand: Clipy XML, TextExpander and aText exports, CLCL `history.dat` + `regist.dat`.

Before a fixture is committed it is OCR'd / grepped for anything real (names, numbers, addresses),
as every screenshot is since 5 Nov.
