# Import from other clipboard and snippet managers (3.1)

Status: design, revision 2 after the auditor's stage-0 review of 5 Nov 2026. Nothing is built
yet. Revision 1 is in the PR history; the review's nine findings and the clarifications are each
answered in the section they concern, marked **(A-n)**.

## Evidence labels

Every claim about another program carries one of:

- `[source: <URL>@<commit>]` — read in that program's source at that commit.
- `[doc: <URL>, <date read>]` — read in the program's official manual.
- `[observed: <URL>]` — a schema or layout published by users, not by the vendor; counts as
  a hypothesis until a fixture confirms it.
- `[fixture: pending]` → `[fixture: Tests/Fixtures/import/<program>/<file>, sha256 <…>,
  <program> <version>]` once Andrey's real file is in the repo.

A parser is written only against a format whose row has a **verified fixture**. The labels in
the source tables below are the current state; the pending ones are listed again in the fixture
checklist. **(A: clarification 1)**

## Why and what

People who try Keepit already have a history and a snippet collection elsewhere. The import brings
those in **once**, into the same stores the app uses. It is not a sync and not a backup: *Settings
→ Backup → Restore* reads `.keepit` files; *Settings → Import* reads other programs' files. The two
share the commit coordinator (see "How it is applied") and nothing else.

Only formats Keepit can read without the other program's help. **Not supported in 3.1**: Paste,
Pastebot, PastePal, Raycast's own clipboard history — their storage and export were not examined
for this design; the pane does not list them, the guide names them under "Not supported" with
exactly that wording. **(A: clarification 5)**

What is taken:

- **History** → history items: plain text, RTF and HTML where present, images, file references,
  the original copy date and source app.
- **Snippets** → templates, in one folder per imported program, the program's own grouping
  beneath it. Placeholders are converted only where the meaning is identical on both sides;
  everything else is kept **literally** — see "Placeholder conversion", which defines what
  "literally" means and how it is tested.
- **Favourites / pins** of the source → the item in the history **and** a copy in a template
  folder `<Program> favourites`, because Keepit's "pin" is a copy into the templates (there is no
  pinned flag on history items; `AppDelegate.historyPinned` creates a `TemplateNode`). The copy
  keeps the item's formats and gets no hot key. When the Templates category is unchecked, favourites
  go to history only and the preview says "pinned status not transferred". **(A-6)**

## Sources

### Wave 1 — ships in 3.1

| Program | What | Where (macOS) | Format | Evidence |
|---|---|---|---|---|
| **Maccy** 2.x | history | `~/Library/Containers/org.p0deje.Maccy/Data/Library/Application Support/Maccy/Storage.sqlite` + `-wal` + `-shm`; sandboxed app; path built as `URL.applicationSupportDirectory.appending("Maccy/Storage.sqlite")` | SwiftData store. Logical model: `HistoryItem(application: String?, firstCopiedAt, lastCopiedAt: Date, numberOfCopies: Int, pin: String?, title: String, contents: [HistoryItemContent])`, `HistoryItemContent(type: String, value: Data?, item)`. `type` is the raw pasteboard type string (`public.utf8-plain-text`, `public.png`, `public.tiff`, `public.rtf`, `public.html`, `public.file-url`, plus Maccy-internal types that are skipped); `value` the raw pasteboard bytes. | `[source: github.com/p0deje/Maccy Models/HistoryItem.swift, HistoryItemContent.swift, Storage.swift @ master 5 Nov 2026]`. Physical table/column names (`ZHISTORYITEM.ZTITLE …`), date epoch, file-URL encoding: `[fixture: pending]` — the SwiftData model is not proof of the SQL layout of every 2.x build |
| **Alfred** 4/5 (Powerpack) | history | `~/Library/Application Support/Alfred/Databases/clipboard.alfdb` (+ `-wal`, `-shm`); Preferences → Advanced → *Reveal in Finder* | SQLite `clipboard(item, ts decimal, app, apppath, dataType integer, dataHash)`; `dataType` 0 text, 1 image, 2 file; image bytes in a sibling directory addressed by `dataHash` | `[observed: rmoff.net/2020/05/18/…, github.com/mxbaylee/alfred-clip.py]` — Alfred is closed; **`[fixture: pending]` decides**: epoch of `ts`, image file layout, what `item` holds for files |
| **Alfred** | snippets | `.alfredsnippets` export (Features → Snippets → collection → Export) | zip: `info.plist` (collection name, keyword prefix/suffix) + one `<uid>.json` per snippet `{"alfredsnippet":{"snippet","uid","name","keyword"}}` | `[observed]` from third-party collections; `[fixture: pending]` |
| **Raycast** | snippets | *Snippets → ⌘K → Export Snippets* → JSON | array of `{"name","text","keyword"?}` | `[doc: manual.raycast.com/snippets#importing-snippets, 5 Nov 2026]` describes the import JSON; the export of the installed version: `[fixture: pending]` |
| **Flycut** | history | `~/Library/Preferences/com.generalarcade.flycut.plist`; App Store build: `~/Library/Containers/com.generalarcade.flycut/Data/Library/Preferences/…` | `NSUserDefaults` key `store` → `jcList` and `favoritesList`, arrays of `{Contents, Type, AppLocalizedName, AppBundleURL, Timestamp, Position}`; `Timestamp` = `timeIntervalSince1970` as integer; text only | `[source: github.com/TermiT/Flycut FlycutOperator.m @ 8a24014 — loadEngineFrom:key:into:, saveStore:toKey:onDict:]`; `Type` values: `[fixture: pending]` |
| **Espanso** | snippets | `~/Library/Application Support/espanso/match/` | YAML match files: `matches: [{trigger \| triggers, replace, label?, vars?: [{name, type, params}], form?, form_fields?}]`; `{{name}}` references; `$\|$` cursor. **Which files count**: every `*.yml`/`*.yaml` under `match/` except names starting with `_` (espanso does not auto-load those); `imports:` entries are followed only when they resolve inside `match/`, others are listed in the preview as "not followed"; `include`/`exclude` and app-specific `config/` are ignored — the import takes the match *definitions*, each template tagged with its file as a sub-folder, not the active per-app library. **(A: clarification 3)** | `[doc: espanso.org/docs/matches/basics, …/organizing-matches, …/extensions, 5 Nov 2026]`; `[fixture: pending]` |

### Wave 2 — after wave 1 is accepted

| Program | What | Format | Evidence |
|---|---|---|---|
| **Clipy / ClipMenu** | snippets | XML `<folders><folder><title/><snippets><snippet><title/><content/></snippet>…</snippets></folder>…</folders>`, one folder level, no placeholders | `[source: github.com/Clipy/Clipy CPYSnippetsEditorWindowController.swift @ d90477d]`; `[fixture: pending]` |
| **TextExpander** | snippets | export file; `%clipboard`, `%\|`, strftime `%Y %m %d %H %M`, `%fill:name%`, `%filltext:name=…:default=…%`, `%fillpopup:name=…:default=a:b%`, `%snippet:abbr%`, `%key:…%` | `[fixture: pending]` for the file; placeholders `[doc: pending]` |
| **aText** | snippets | export file; TextExpander-style `%…%` | `[fixture: pending]` |
| **CLCL** (Windows) | history + templates | `history.dat`, `regist.dat`, binary; parser from the C source | `[source: pending — nakkag/CLCL]`, `[fixture: pending]` from Andrey's Windows copy |

## Reading files safely

### SQLite (Maccy, Alfred) **(A-1)**

A copy of `db` + `-wal` + `-shm` taken while the owner is running can be three files from three
moments; opening that copy read-only does not make it consistent, and opening the *live* database
as a second reader creates or rewrites `-shm` in the owner's folder, which the privacy contract
forbids. So:

1. **The source program must be quit.** `detect()` checks `NSWorkspace.shared.runningApplications`
   for the bundle id; while it runs, the row says *Quit Maccy, then import* and the button is
   disabled. No backup API, no live read.
2. The **complete set** (`.sqlite` and, when present, `-wal`, `-shm`; for Alfred also the image
   directory) is copied to a private temp directory (0700, files 0600) and only the copy is opened,
   `?mode=ro`, never `immutable=1`. SQLite recovers the copied WAL into the copy; nothing is written
   back. A `.sqlite` without the `-wal` that sits beside it is an error, not a partial import.
3. **Sandboxed build**: the open panel asks for the **folder** (`Maccy/`, `Databases/`) with
   `canChooseDirectories`, so the security-scoped URL covers every sidecar. A single file chosen
   where sidecars exist is refused with "choose the folder".

### Archives and markup **(A-9)**

| Input | Rules |
|---|---|
| any file | size ≤ `Limits.dataFileMaxBytes` (512 MB) before it is opened; rows/entries read ≤ 100 000; time budget with a Cancel button on the progress sheet; whole import cancellable |
| `.alfredsnippets` (zip) | entries ≤ 10 000, uncompressed total ≤ 64 MB, each entry ≤ `textBytesCeiling`; entry names with `..`, absolute paths, or symlinks are rejected (the archive is refused, not skipped) |
| XML (Clipy) | Foundation `XMLParser` with `shouldResolveExternalEntities = false`, DTD/entity declarations rejected; depth ≤ 16 |
| YAML (Espanso) | parsed with **Yams**, pinned by SHA in `Package.resolved` like Sparkle, safe schema only (no tags/constructors), anchors/aliases ≤ 100, depth ≤ 16, file ≤ 8 MB. *Decision for the auditor*: Yams as a second dependency vs. a subset parser written here; the subset parser is more code to audit, Yams is more surface — recommended Yams |
| JSON (Raycast) | `JSONDecoder`, array only, ≤ 10 000 snippets |
| plist (Flycut) | `PropertyListSerialization` with `.immutable`, root dictionary only |
| per item | text ≤ `Limits.textBytesCeiling`; images ≤ `imageBytesCeiling` and ≤ `imageMaxPixels` (decoded through the same bomb check as the monitor); file lists ≤ `fileListEntriesCeiling` and **never opened or stat'ed** — paths are stored as strings |
| nested snippets | one level, never recursive (Alfred does not resolve nested `{snippet:}` either `[doc: alfredapp.com/help/workflows/advanced/placeholders/#snippets]`, Raycast's referenced snippet cannot reference further); the target is looked up by resolved keyword (collection prefix + keyword + suffix for Alfred), among the snippets of the same import only; missing or ambiguous target → literal + attention **(A: clarification 4)** |
| Espanso `shell`, `script`, `echo`, `random`, `match` vars | never executed; `echo` with a literal `echo` param is inlined, the rest literal + attention |
| temp copies | private dir 0700 / files 0600, removed when the import finishes, is cancelled or fails; leftovers from a crash are removed at launch (`import-tmp-*` under the app's cache dir); no clip content in logs; no claim of physical erasure |

## Placeholder conversion

### The literal contract **(A-2)**

The converter produces the template text in two kinds of pieces: **converted tokens** (`{date}`,
`{input:Name}` …) and **literal text**. Literal text is escaped so that Keepit's engine reproduces
it exactly: every `{` becomes `{{`, every `}` becomes `}}`. This covers unsupported placeholders
(`{random:a,b}` → `{{random:a,b}}` → pastes as `{random:a,b}`), token names that collide with
Keepit's (`{query}`), and plain braces in code or JSON.

Two engine changes make that hold at paste time, each with a test and a CHANGELOG line:

1. **The paste gate.** `Snippets.containsPlaceholders` is `{` + letter today, so `{{"x":1}}` is
   pasted with doubled braces. It becomes `Snippets.needsExpansion(_:)` = contains `{{`, `}}` or a
   `{letter…}` token. Note the behaviour change for existing templates: `{{` in a template pastes
   as `{` from 3.1, which is what the guide has promised since the cheat sheet row "`{{` `}}` —
   literal braces"; CHANGELOG says so.
2. **Round-trip test, not converter test.** The table-driven tests assert on
   `Snippets.expand(converted, context: fixed).text`, with a fixed clock, clipboard and answers,
   not on the converter's output: for every source string the pasted text must equal the original
   with exactly the converted tokens replaced. The auditor's five counterexamples go into that
   table as the first rows.

"Needs attention" is a count and a list in the preview and the result — it does not change what
the engine does with the text.

### What is converted (exact subset) **(A-3)**

Only where meaning is identical. The engine is extended in three small, tested places so that the
common cases *are* identical rather than approximated:

- `{date:short|medium|long|full}`, same for `time`/`datetime`: DateFormatter styles (Alfred's named
  formats; Alfred's bare `{date}` is **medium**, Keepit's is short — so Alfred `{date}` →
  `{date:medium}`, not `{date}`).
- Shifts on `time` and `datetime` as on `date`, and **several** shifts in one token:
  `{date+1y-2d}`. Units stay `d w m y h` (Keepit `m` = month).
- Minutes and seconds are not added: a source shift in minutes/seconds is literal + attention.

| Meaning | Alfred `[doc]` | Raycast `[doc]` | Espanso `[doc]` | Keepit |
|---|---|---|---|---|
| clipboard | `{clipboard}`, `{clipboard:0}` | `{clipboard}` | var `type: clipboard` | `{clipboard}` |
| older clipboard item N | `{clipboard:N}` | `{clipboard offset=N}` | — | `{clipboard:N+1}` |
| cursor | `{cursor}` | `{cursor}` | `$\|$` | `{cursor}` |
| date, named style | `{date}`=medium, `{date:short\|medium\|long\|full}`; same for `time`, `datetime` | `{date}` `{time}` `{datetime}` = system default | var `type: date` without `format` | `{date:medium}` etc.; Raycast's default style: literal + attention until the manual states it |
| date, Unicode pattern | `{date:EEEE}` | `{date format="yyyy-MM-dd"}` (no `locale`) | — (strftime) | `{date:EEEE}` / `{date:yyyy-MM-dd}` |
| date, strftime pattern | — | — | `params.format: "%Y-%m-%d"` | converted token by token for `%Y %m %d %H %M %S %A %B %a %b %e %j %p %y`; any other `%x` → whole token literal + attention |
| shift | `{date +7D}` units `Y M D h` (`m`=minute, `s`=second) | `{date offset="+2y +5M"}` (`m`=minute) | `params.offset` (seconds) | `{date+7d}` with `Y→y M→m D→d h→h`; several shifts kept in order; `m`/`s` of the source → literal + attention; Espanso seconds → literal + attention (an instant offset ≠ a calendar day across DST) |
| weekday | — | `{day}` | — | `{weekday}` |
| ask for text | — | `{argument name="x" default="y"}` | `[[x]]` / form field `type: text` | `{input:x=y}` — only when `x` and `y` contain none of `{ } \| = :` and `x` is non-empty; else literal + attention |
| ask to pick | — | `{argument name="x" options="a, b"}` | form field `type: choice` with `values` | `{choice:x=a\|b}` — same character rule, values trimmed |
| UUID | `{random:UUID}` | `{uuid}` | — | `{uuid}` |
| random number | `{random:1..5}` | — | — | `{random:1-5}` |
| nested snippet | `{snippet:kw}` | `{snippet name="…"}` | var `type: match` | inlined one level (rules above) |
| text filters | `.uppercase .lowercase .trim` on clipboard | `\| uppercase \| lowercase \| trim` | — | `\|upper \|lower \|trim`; other modifiers → literal + attention |
| everything else | `{query}` `{var:}` `{random:a,b}` `{isodate}`… | `{selection}` `{calculator}` `{browser-tab}` `{snippet}` to a missing target, `locale=` | `shell` `script` `random` `form` with layout | literal + attention |

Keywords/triggers: Keepit has no trigger expansion. A snippet's keyword is kept in the template
name as `Name (keyword)` when the program has no separate name (Espanso `trigger` without `label`,
Raycast without `name`); otherwise it is dropped — and the preview says *N keywords not carried
over (Keepit has no abbreviation expansion)*. **(A: clarification 4b)** Hot keys are never assigned.

## How it is applied **(A-4, A-5, A-7)**

### Models

`KeepitCore` cannot return `ClipItem` (imports AppKit, lives in the app target) or `TemplateNode`
(app target, mutable graph). `KeepitCore/Import` defines value types:

```
ImportedItem     { formats: [String: Data] /* raw pasteboard UTI → bytes */, date: Date?,
                   source: ImportedSource?, favourite: Bool, origin: String /* row id / path for notes */ }
ImportedSource   { bundleID: String?, name: String?, path: String? }   // kept apart; normalised later
ImportedTemplate { name: String, pieces: [Piece] /* .literal(String) | .token(String) */, origin: String }
ImportedFolder   { name: String, templates: [ImportedTemplate], folders: [ImportedFolder] }
ImportNote       { origin: String, kind: .unsupportedPlaceholder(String) | .keywordDropped(String)
                   | .importNotFollowed(String) | .unreadable(String) }
ImportPayload    { history: [ImportedItem], favourites: [ImportedItem], templates: ImportedFolder?, notes: [ImportNote] }
```

The **app-side adapter** (`ImportAdapter`, app target) turns that into `ClipItem` / `TemplateNode`:
TIFF → PNG through the existing image path, `public.file-url` rows → Keepit's file-list JSON (paths
as strings, nothing opened), RTF/HTML kept beside the text, `contentHash` computed by Keepit's own
rule (`Backup.validate`'s), never taken from the source; `sourceApp` = bundle id when the source
has one, else the app name (Keepit's field is a single string). Limits that live in the app target
are checked here; `KeepitCore` checks byte and count budgets.

### Plan

`RestorePlan.make(mode: .merge …)` is reused with two changes, each with a test in
`RestorePlanTests`:

- an empty `payload.templates` (no children) creates **no** folder — today a history-only merge
  leaves an empty "Imported …" folder (auditor's test 2);
- the plan reports, separately: `historyDuplicates` (already present by content hash),
  `historyAdded`, `historyDropped` (over the ring / age / byte budget — auditor's test 1),
  `templatesAdded`, `favouritesAdded`.

The import pane's two checkboxes build the payload: *History* off → `history: []` and favourites
go nowhere; *Templates* off → `templates: nil`, favourites not copied. Nothing new at all →
"Nothing to import" and no commit.

**Preview** shows those numbers as they will be stored, and when `historyDropped > 0` it says
*N items will not fit the history limits (Settings → History)* and the button reads *Import
anyway*. **Repeated import**: history is idempotent by content hash; templates are **not**
deduplicated in 3.1 — when a folder named `Imported from <Program>…` already exists the preview
says *A previous import exists; importing again adds another copy of the templates* (auditor's
test 3). Template identity/dedup is a possible later item, not promised. **(A-5)**

### Commit

The commit is the **same coordinator** Restore uses, extracted from `RestoreActions` into one
function both call (`applyMergePlan`): plan recomputed after the dialogs, `DataStamp` check,
`lockCount`, monitor paused, pending saves flushed, `RestoreCommit.writeFiles` with the journal,
stores assigned, monitor resumed; a failed undo → `stopForUnfinishedUndo`, never "carry on
saving". No rollback copy (Merge adds). No settings touched.

## Detect and privacy **(A-8)**

Before the user clicks anything the pane only checks **file presence and access**, never content:

| Row status | Meaning |
|---|---|
| *Found* | file exists and is readable |
| *Quit Maccy, then import* | file found, owner running (SQLite sources only) |
| *Not found* | no file at the known paths |
| *Choose folder…* | sandboxed build, or found but unreadable — "not readable" is never shown as "not found" |

Counts, dates and everything else are read only after *Import…* is clicked, on the preview step,
in the background with the progress sheet. The guide and the privacy policy word it as: *Keepit
reads another app's data only when you click Import, and only the file you point it at.*

## Settings → Import (pane)

After *Backup*, before *Advanced*. Group **From another app on this Mac**: a row per wave-1 program
— name, status from the table above, *Import…*. Group **From a file**: *Choose file or folder…*
accepting every importer's types. (?) texts say what is taken, what is not, and that the other
program is not changed. Same grammar as the other panes.

## What is not done

No sync; no settings, hot keys or ignore lists from the other program; no writing back; no
template dedup across imports; no closed stores (see above); export to other programs is the
separate 3.1 roadmap item.

## Stages and the audit

0. This document (rev. 2) → auditor.
1. **Engine changes first**, as their own PR: `needsExpansion`, date styles, shifts on
   time/datetime, several shifts per token; CHANGELOG lines; the round-trip test table seeded with
   the auditor's counterexamples. Nothing import-specific in this PR.
2. `KeepitCore/Import`: models, `Importer` protocol, safe readers (zip, XML, YAML, SQLite copy),
   one reader per verified fixture — Maccy, Alfred history, Alfred snippets, Raycast, Flycut,
   Espanso; placeholder converter as a pure function with the table tests.
3. Adapter + `RestorePlan` changes + the shared commit coordinator; `RestorePlanTests` for the
   empty-folder and the counts; journal-interruption tests reused.
4. Pane, preview, result; guide chapter; privacy policy sentence; screenshots; CHANGELOG.
5. Wave 2, one PR per program.

Each stage: draft PR, auditor's findings become tests, next stage only after "no further findings".

## Fixture checklist (Andrey)

In each history manager copy the same set: three texts (one multi-line, one with non-Latin text
and an emoji), a URL, an image, a file from the Finder, an RTF fragment; pin/favourite one item
where the program can. In each snippet manager: a plain snippet; one with date + clipboard +
cursor; one with an input field (where supported); inside one folder/group; one with a nested
snippet where supported. Then, with the program **quit**:

- Maccy: the `Maccy/` folder (sqlite + wal + shm) zipped; Maccy's version (About).
- Alfred: the `Databases/` folder zipped (clipboard.alfdb + sidecars + image files) and the
  `.alfredsnippets` export of the test collection; Alfred's version.
- Raycast: the exported JSON; Raycast's version.
- Flycut: `com.generalarcade.flycut.plist`; version.
- Espanso: the `match/` folder; `espanso --version`.
- Wave 2 when at hand: Clipy XML, TextExpander and aText exports, CLCL `history.dat` + `regist.dat`.

Every fixture is grepped/OCR'd for anything real before it is committed, and its row in the tables
above gets the path, sha256 and program version.
