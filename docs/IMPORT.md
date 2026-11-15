# Import from other clipboard and snippet managers

Status: design, **revision 5** (14 Nov 2026). Revision 4 was accepted on 5 Nov after the auditor's
three stage-0 reviews; of the import itself nothing is built yet. Revision 5 re-bases the design on
`main` after 3.0.7 (`3a7f3eb`): every mechanism the import commits through was reworked in 3.0.6
(held files, journaled commits, lock surfaces) and 3.0.7 (file limits, 0700/0600), and macOS itself
changed what one program may read of another's. What is new is in "What 3.0.6 and 3.0.7 changed
under this design" and in the "Failure table", and is marked **(D-n)** where it touches an older
section. The older marks stay: the first review's nine findings **(A-n)**, the second review's four
clarifications **(B-n)**, the third review's YAML point **(C-1)**. The five decisions of revision 4
that change are listed at the end of the D section; everything else stands as accepted.

Release: the import ships in the release after 3.0.7. Whether that is numbered 3.0.8 or 3.1.0 is
decided at the release PR; this document says "the import release". The container format does not
change: `Backup.minReader` stays 3.0 and `readerVersion` follows `VERSION` as always.

## Evidence labels

Every claim about another program carries one of:

- `[source: <URL>@<commit>]` — read in that program's source at that commit.
- `[doc: <URL>, <date read>]` — read in the program's official manual.
- `[observed: <URL>]` — a schema or layout published by users, not by the vendor; counts as
  a hypothesis until a fixture confirms it.
- `[fixture: pending]` → `[fixture: Tests/KeepitTests/Fixtures/import/<program>/<file>, sha256 <…>,
  <program> <version>]` once Andrey's real file is in the repo. **(D-10)**

A parser is written only against a format whose row has a **verified fixture**. The labels in
the source tables below are the current state; the pending ones are listed again in the fixture
checklist. **(A: clarification 1)**

## Why and what

People who try Keepit already have a history and a snippet collection elsewhere. The import brings
those in **once**, into the same stores the app uses. It is not a sync and not a backup: *Settings
→ Backup → Restore* reads `.keepit` files; *Settings → Import* reads other programs' files. The two
share the commit coordinator (see "How it is applied") and nothing else.

Only formats Keepit can read without the other program's help. **Not supported in the import
release**: Paste, Pastebot, PastePal, Raycast's own clipboard history — their storage and export
were not examined
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
  **The copy is literal (B-1).** A favourite was static text in the source, so its template copy
  must paste exactly those bytes: the history item keeps the source bytes untouched; the template
  copy gets the same formats, with its plain-text format run through the same escaping as snippet
  literals (`{`→`{{`, `}`→`}}`), and the rich formats (RTF, HTML, PNG, file list) copied as they
  are. The paste path then has nothing to execute (see "Paste route" below) and pastes the clip
  with all its formats — no clipboard lookup, no `{input:}` prompt, no `{cursor}` caret move. This
  is an import rule only; the user's own *Pin* keeps today's behaviour. Tests: favourites whose
  text is `{clipboard}`, `{input:x}`, `{cursor}` and a JSON object — history bytes equal the source,
  the template paste equals the source text, RTF/HTML survive.

## Sources

### Wave 1 — the import release

| Program | What | Where (macOS) | Format | Evidence |
|---|---|---|---|---|
| **Maccy** 2.x | history | `~/Library/Containers/org.p0deje.Maccy/Data/Library/Application Support/Maccy/Storage.sqlite` + `-wal` + `-shm`; sandboxed app; path built as `URL.applicationSupportDirectory.appending("Maccy/Storage.sqlite")` | SwiftData store. Logical model: `HistoryItem(application: String?, firstCopiedAt, lastCopiedAt: Date, numberOfCopies: Int, pin: String?, title: String, contents: [HistoryItemContent])`, `HistoryItemContent(type: String, value: Data?, item)`. `type` is the raw pasteboard type string (`public.utf8-plain-text`, `public.png`, `public.tiff`, `public.rtf`, `public.html`, `public.file-url`, plus Maccy-internal types that are skipped); `value` the raw pasteboard bytes. | `[source: https://github.com/p0deje/Maccy/blob/f0b571e/Maccy/Models/HistoryItem.swift, …/HistoryItemContent.swift, …/Storage.swift]`. Physical table/column names (`ZHISTORYITEM.ZTITLE …`), date epoch, file-URL encoding: `[fixture: pending]` — the SwiftData model is not proof of the SQL layout of every 2.x build |
| **Alfred** 4/5 (Powerpack — Andrey has it, so Alfred stays in wave 1) | history | `~/Library/Application Support/Alfred/Databases/clipboard.alfdb` (+ `-wal`, `-shm`); Preferences → Advanced → *Reveal in Finder* | SQLite `clipboard(item, ts decimal, app, apppath, dataType integer, dataHash)`; `dataType` 0 text, 1 image, 2 file; image bytes in a sibling directory addressed by `dataHash` | `[observed: https://rmoff.net/2020/05/18/searching-alfreds-clipboard-history-programatically/, https://github.com/mxbaylee/alfred-clip.py]` — Alfred is closed; **`[fixture: pending]` decides**: epoch of `ts`, image file layout, what `item` holds for files |
| **Alfred** | snippets | `.alfredsnippets` export (Features → Snippets → collection → Export) | zip: `info.plist` (collection name, keyword prefix/suffix) + one `<uid>.json` per snippet `{"alfredsnippet":{"snippet","uid","name","keyword"}}` | `[observed: https://github.com/alfredapp/snippets — the structure of the published collections]`; `[fixture: pending]` |
| **Raycast** | snippets | *Snippets → ⌘K → Export Snippets* → JSON | array of `{"name","text","keyword"?}` | `[doc: manual.raycast.com/snippets#importing-snippets, 5 Nov 2026]` describes the import JSON; the export of the installed version: `[fixture: pending]` |
| **Flycut** | history | `~/Library/Preferences/com.generalarcade.flycut.plist`; App Store build: `~/Library/Containers/com.generalarcade.flycut/Data/Library/Preferences/…` | `NSUserDefaults` key `store` → `jcList` and `favoritesList`, arrays of `{Contents, Type, AppLocalizedName, AppBundleURL, Timestamp, Position}`; `Timestamp` = `timeIntervalSince1970` as integer; text only | `[source: https://github.com/TermiT/Flycut/blob/8a24014/FlycutOperator.m — loadEngineFrom:key:into:, saveStore:toKey:onDict:]`; `Type` values: `[fixture: pending]` |
| **Espanso** | snippets | `~/Library/Application Support/espanso/match/` | YAML match files: `matches: [{trigger \| triggers, replace, label?, vars?: [{name, type, params}], form?, form_fields?}]`; `{{name}}` references; `$\|$` cursor. **Which files count**: every `*.yml`/`*.yaml` under `match/` except names starting with `_` (espanso does not auto-load those); `imports:` entries are followed only when they resolve inside `match/`, others are listed in the preview as "not followed"; `include`/`exclude` and app-specific `config/` are ignored — the import takes the match *definitions*, each template tagged with its file as a sub-folder, not the active per-app library. **(A: clarification 3)** | `[doc: espanso.org/docs/matches/basics, …/organizing-matches, …/extensions, 5 Nov 2026]`; `[fixture: pending]` |

### Wave 2 — after wave 1 is accepted

| Program | What | Format | Evidence |
|---|---|---|---|
| **Clipy / ClipMenu** | snippets | XML `<folders><folder><title/><snippets><snippet><title/><content/></snippet>…</snippets></folder>…</folders>`, one folder level, no placeholders | `[source: https://github.com/Clipy/Clipy/blob/d90477d/Clipy/Sources/Snippets/CPYSnippetsEditorWindowController.swift]`; `[fixture: pending]` |
| **TextExpander** | snippets | export file; `%clipboard`, `%\|`, strftime `%Y %m %d %H %M`, `%fill:name%`, `%filltext:name=…:default=…%`, `%fillpopup:name=…:default=a:b%`, `%snippet:abbr%`, `%key:…%` | `[fixture: pending]` for the file; placeholders `[doc: pending]` |
| **aText** | snippets | export file; TextExpander-style `%…%` | `[fixture: pending]` |
| **CLCL** (Windows) | history + templates | `history.dat`, `regist.dat`, binary; parser from the C source | `[source: pending — nakkag/CLCL]`, `[fixture: pending]` from Andrey's Windows copy |

## Reading files safely

### SQLite (Maccy, Alfred) **(A-1)**

A copy of `db` + `-wal` + `-shm` taken while the owner is running can be three files from three
moments; opening that copy read-only does not make it consistent, and opening the *live* database
as a second reader can create or rewrite `-shm` in the owner's folder, which the privacy contract
forbids. So:

1. **The source program must be quit — checked at the moment it matters (B-3).** `detect()`
   checks `NSWorkspace.shared.runningApplications` for the bundle id to label the row (*Quit Maccy,
   then import*); that label is advisory. The binding check is **immediately before the copy
   starts**, again for *From a file/folder* (every importer whose known path contains the chosen
   folder contributes its bundle id), and **during the copy**: the set's sizes and modification
   dates are recorded before, compared after each file and once more at the end, and a launch of
   the owner is watched (`NSWorkspace.didLaunchApplicationNotification`) for the whole snapshot.
   Any change or launch → the temp copy is discarded, nothing is read, the sheet says *Maccy was
   started while Keepit was reading its history — quit it and try again*. For a folder whose owner
   Keepit does not know, no "offline" claim is made: the sheet says *make sure the app that owns
   this folder is closed* and the same size/date check applies. No backup API, no live read.
2. The **complete set** (`.sqlite` and, when present, `-wal`, `-shm`; for Alfred also the image
   directory) is copied to a private temp directory (0700, files 0600) and only the copy is opened,
   `?mode=ro`, never `immutable=1`. SQLite recovers the copied WAL into the copy; nothing is written
   back. A `.sqlite` without the `-wal` that sits beside it is an error, not a partial import.
3. **Sandboxed build**: the open panel asks for the **folder** (`Maccy/`, `Databases/`) with
   `canChooseDirectories`, so the security-scoped URL covers every sidecar. A single file chosen
   where sidecars exist is refused with "choose the folder".

How the copy is made, where it lives, what "complete" means after a clean quit, and how the copy
is opened as an untrusted database: **D-5**. What macOS lets Keepit read of another program's
folder at all: **D-8**.

### Archives and markup **(A-9)**

| Input | Rules |
|---|---|
| any file | size ≤ `Limits.dataFileMaxBytes` (512 MB) before it is opened (the one-call parsers lower — JSON, plist and the zip file ≤ 64 MB, **D-5**); rows/entries read ≤ 100 000; time budget with a Cancel button on the progress sheet; whole import cancellable between files and between rows (a single synchronous parser call is bounded by its file-size limit, not by Cancel) |
| whole job | copied snapshot ≤ 2 GB and ≤ 10 000 files in total; decoded payload ≤ 1 GB; history items ≤ `historyMaxCeiling` × 2 read before the plan trims; templates read ≤ `templateMaxCount`; nested-snippet inlines ≤ 20 000 per job. Checked while reading, before the next file or row is taken |
| `.alfredsnippets` (zip; the reader is Keepit's own, **D-5**) | entries ≤ 10 000, uncompressed total ≤ 64 MB, each entry ≤ `textBytesCeiling`; entry names with `..`, absolute paths, or symlinks are rejected (the archive is refused, not skipped) |
| XML (Clipy) | Foundation `XMLParser` with `shouldResolveExternalEntities = false`, DTD/entity declarations rejected; depth ≤ 16 |
| YAML (Espanso) | **Yams** (auditor's choice confirmed): a named release pinned by revision in `Package.resolved` at stage 2, under the same `check_resolved.sh` drift check as Sparkle; the API statements below are re-checked against **that** revision, not `main`. The wrapper decodes into the espanso DTOs only and rejects unknown custom tags. **Preflight before any tree is built (C-1)**: Yams' public surface is `compose`/`decode`, which build the node tree with recursive loaders — `Parser.parse()` and `Event` are not public and `CYaml` is an implementation-only import — so the preflight cannot be "Yams' event stream". It is a separate bounded pass over the libyaml **event** API (our own thin C-interop target over the libyaml that Yams vendors, or the system/Homebrew libyaml, decided at stage 2), run before Yams sees the bytes: it rejects anchors and aliases (the alias count does not bound the expanded graph: 10 levels × 8 references ≈ 8¹⁰ visits), tags outside the core schema, nesting depth > 16, and more than 50 000 events / 100 000 nodes-equivalent; file ≤ 8 MB. It is a parser-level check, not a character search in the text. **Gate**: a small prototype with the auditor's 8¹⁰ document and a 10 000-deep document must be refused within the budgets before the YAML reader is accepted at stage 2; without a working preflight the Espanso reader is **not** shipped. Espanso match files in practice use neither anchors nor deep nesting |
| JSON (Raycast) | `JSONDecoder`, array only, ≤ 10 000 snippets |
| plist (Flycut) | `PropertyListSerialization` with `.immutable`, root dictionary only |
| per item | text ≤ `Limits.textBytesCeiling`; images ≤ `imageBytesCeiling` and ≤ `imageMaxPixels` (decoded through the same bomb check as the monitor); file lists ≤ `fileListEntriesCeiling` and **never opened or stat'ed** — paths are stored as strings |
| nested snippets | one level, never recursive (Alfred does not resolve nested `{snippet:}` either `[doc: https://www.alfredapp.com/help/workflows/advanced/placeholders/#snippets]`, Raycast's referenced snippet cannot reference further); the target is looked up by resolved keyword (collection prefix + keyword + suffix for Alfred), among the snippets of the same import only; missing or ambiguous target → literal + attention **(A: clarification 4)** |
| Espanso `shell`, `script`, `random` vars | never executed, never evaluated: literal + attention. `echo` with a literal `echo` param is inlined; `match` is the one-level nested snippet of the row above |
| temp copies | private dir 0700 / files 0600, removed when the import finishes, is cancelled or fails; leftovers from a crash are removed at launch (`import-tmp-*` under the app's cache dir); no clip content in logs; no claim of physical erasure. Streaming, `O_NOFOLLOW`, lifetime and the report of a leftover: **D-5** |

## Placeholder conversion

### The literal contract **(A-2)**

The converter produces the template text in two kinds of pieces: **converted tokens** (`{date}`,
`{input:Name}` …) and **literal text**. Literal text is escaped so that Keepit's engine reproduces
it exactly: every `{` becomes `{{`, every `}` becomes `}}`. This covers unsupported placeholders
(`{random:a,b}` → `{{random:a,b}}` → pastes as `{random:a,b}`), token names that collide with
Keepit's (`{query}`), and plain braces in code or JSON.

Two engine changes make that hold at paste time, each with a test and a CHANGELOG line. **Both
shipped in 3.0.5 (PR #30; `Snippets.pasteRoute`, `SnippetRouteTests`)** — they stay here as the
contract the converter is written against; the limits the engine has gained since are in **D-9**:

1. **The paste route.** Today `pasteTemplate` decides with `Snippets.containsPlaceholders` (`{` +
   letter): a template with only `{{`/`}}` skips expansion and pastes doubled braces, and a template
   that is expanded is pasted as a new plain-text `ClipItem`, dropping RTF/HTML. The decision moves
   into one pure function, `Snippets.pasteRoute(for clip:) -> Route`, with three outcomes:
   `.verbatim` (no `{`-syntax at all: the clip pastes with every format, as today),
   `.unescapeOnly(text)` (escapes but no tokens: paste the clip with **all its formats** and the
   plain-text format replaced by the unescaped text — for an imported favourite that equals the
   source bytes), `.expand(text, prompts)` (tokens present: the expanded plain text, as today).
   `pasteTemplate` switches on the route and nothing else. Implementation note from the auditor's
   third review: `ClipItem.setText` drops RTF/HTML, so the `.unescapeOnly` branch must build the
   pasted item from the original formats with only the plain-text entry replaced — the tests for
   rich favourites catch a `setText` shortcut. Behaviour change for existing templates:
   `{{` pastes as `{` since 3.0.5, which the cheat sheet row "`{{` `}}` — literal braces" has promised;
   CHANGELOG says so.
2. **Tests on the route, not only on `expand` (B-2).** `Snippets.expand` already handles
   `{{"x":1}}` correctly — the bug is the gate — so a test that calls `expand` directly is green on
   3.0.3. The table therefore asserts, per row: the route chosen (`.verbatim` / `.unescapeOnly` /
   `.expand`), the pasted plain text from a fixed context (clock, clipboard provider, answers), and
   for rich rows that the pasted `ClipItem` still carries its RTF/HTML. The escape-only and the
   rich-text rows fail on the 3.0.3 gate by construction. The two Snippets counterexamples from the
   auditor's stage-0 tests (escaped JSON, `{random:a,b}`) are the first rows; the three RestorePlan
   counterexamples (full ring, empty folder, repeated collection) go to `RestorePlanTests`.

"Needs attention" is a count and a list in the preview and the result — it does not change what
the engine does with the text. Two invariants are tests, not prose: an imported template or
favourite never opens a file reference it contains, and no provider (`shell`, `script`, `echo` of
another kind) is ever run — the readers are given a payload full of such entries and the test
asserts no process was spawned and no file was touched.

### What is converted (exact subset) **(A-3)**

Only where meaning is identical. The engine was extended in three small, tested places (3.0.5) so
that the common cases *are* identical rather than approximated:

- `{date:short|medium|long|full}`, same for `time`/`datetime`: DateFormatter styles (Alfred's named
  formats; Alfred's bare `{date}` is **medium**, Keepit's is short — so Alfred `{date}` →
  `{date:medium}`, not `{date}`).
- Shifts on `time` and `datetime` as on `date`, and **several** shifts in one token:
  `{date+1y-2d}`. Units stay `d w m y h` (Keepit `m` = month).
- Minutes and seconds are not added: a source shift in minutes/seconds is literal + attention.

| Meaning | Alfred `[doc]` | Raycast `[doc]` | Espanso `[doc]` | Keepit |
|---|---|---|---|---|
| clipboard | `{clipboard}`, `{clipboard:0}` | `{clipboard}` | var `type: clipboard` | `{clipboard}` — Keepit reads history item 1, not `NSPasteboard`; while recording is paused or the last copy was ignored the two differ. Converted (the user's intent is the same), noted in the guide chapter, not claimed identical |
| older clipboard item N | `{clipboard:N}` | `{clipboard offset=N}` | — | `{clipboard:N+1}` |
| cursor | `{cursor}` | `{cursor}` | `$\|$` | `{cursor}` |
| date, named style | `{date}`=medium, `{date:short\|medium\|long\|full}`; same for `time`, `datetime` | `{date}` `{time}` `{datetime}` = system default | var `type: date` without `format` | `{date:medium}` etc.; Raycast's default style: literal + attention until the manual states it |
| date, Unicode pattern | `{date:EEEE}` | `{date format="yyyy-MM-dd"}` (no `locale`) | — (strftime) | `{date:EEEE}` / `{date:yyyy-MM-dd}` |
| date, strftime pattern | — | — | `params.format: "%Y-%m-%d"` | converted token by token for `%Y %m %d %H %M %S %A %B %a %b %j %p %y` only; `%e` (space-padded day, no ICU equivalent) and any other `%x` → whole token literal + attention **(B-4)**. Literal text between conversions is quoted for ICU (`Today %Y` → `'Today 'yyyy`, a `'` in the literal doubled), with round-trip tests for 1, 9, 10 and 31 of a month. A `date` var with `locale` or `tz` params → whole var literal + attention |
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

The plan is recomputed in the commit stage (the stores may have changed while the preview was
open); when the recomputed `historyDropped` is higher, or `historyAdded`/`templatesAdded` lower,
than the confirmed numbers, the commit stops and the preview is shown again with the new numbers —
never a silent change of what was confirmed.

**Preview** shows those numbers as they will be stored, and when `historyDropped > 0` it says
*N items will not fit the history limits (Settings → History)* and the button reads *Import
anyway*. **Repeated import**: history is idempotent by content hash; templates are **not**
deduplicated in this release — when a folder named `Imported from <Program>…` already exists the preview
says *A previous import exists; importing again adds another copy of the templates* (auditor's
test 3). Template identity/dedup is a possible later item, not promised. **(A-5)**

### Commit

The commit is the **same coordinator** Restore uses, extracted from `RestoreActions` into one
function both call (`applyMergePlan`): plan recomputed after the dialogs, `DataStamp` check,
`lockCount`, monitor paused, pending saves flushed, `RestoreCommit.writeFiles` with the journal,
stores assigned, monitor resumed; a failed undo → `stopForUnfinishedUndo`, never "carry on
saving". No rollback copy (Merge adds). No settings touched.

On today's code: `AppDelegate.commit(_:newVault:)` is that coordinator's inner half and is called
as it is; what is extracted is the commit stage around it. **D-1** has the function, **D-2** the
refusals, **D-3** the limits, **D-7** the texts.

## Detect and privacy **(A-8)**

Before the user clicks anything the pane only checks **file presence and access**, never content:

| Row status | Meaning |
|---|---|
| *Found* | file exists and is readable (sources outside any sandbox container) |
| *Installed* | the program is installed and its data is inside its own sandbox container, which the pane does not open — **D-8** |
| *Quit Maccy, then import* | file found, owner running (SQLite sources only) |
| *Not found* | no file at the known paths |
| *Choose folder…* | sandboxed build, or found but unreadable, or macOS refused the folder at the click — "not readable" is never shown as "not found" |

Counts, dates and everything else are read only after *Import…* is clicked, on the preview step,
in the background with the progress sheet. The guide and the privacy policy word it as: *Keepit
reads another app's data only when you click Import, and only the file or folder you point it at —
for a database, the folder with its companion files.*

## Settings → Import (pane)

After *Backup*, before *Advanced* (**D-10**). Group **From another app on this Mac**: a row per
wave-1 program
— name, status from the table above, *Import…*. Group **From a file**: *Choose file or folder…*
accepting every importer's types. (?) texts say what is taken, what is not, and that the other
program is not changed. Same grammar as the other panes. The progress panel, the preview and the
result are app-modal and close on a lock: **D-6**.

## What is not done

No sync; no settings, hot keys or ignore lists from the other program; no writing back; no
template dedup across imports; no closed stores (see above); export to other programs is a
separate roadmap item. No keepit:// command, no file type of another program opened by
double-click, no import offered at first launch, nothing in the background (**D-10**).

## What 3.0.6 and 3.0.7 changed under this design (rev. 5)

Rev. 4 was written against 3.0.3. The sections above are kept as accepted; this section says how
each of them lands on today's code. Names are those of `main` at `3a7f3eb`.

### D-1 · The commit is the Restore commit, as it is now

Rev. 4 asked for a coordinator "extracted from `RestoreActions`". Half of it exists since
3.0.5–3.0.6: `AppDelegate.commit(_ plan: RestorePlan, newVault:)` — flush both stores, encode,
`RestoreCommit.writeFiles` through the `restore` journal (held-file refusal, previous bytes
readable, `stepOverLimit`, no armed journal, journal → three writes → disarm = the commit point →
sweep), then `history.publish` / `templates.publish` / `apply(settings:)` in one step, and
`lockedAfterWrite` when a lock landed in a callback. The import calls it unchanged, with
`newVault: nil`.

What is still inline in `restore(from:)` is the **commit stage** around it: the watcher stopped, at
most three rounds of *stamp → plan → (Replace: rollback copy; stamp moved → again) → commit*, the
error mapping, and `stopForUnfinishedUndo` when a journal stays armed. That loop becomes one
function both flows call — the `applyMergePlan` of rev. 4, for either mode:

```
runCommitStage(lockAtStart:, makePlan:, beforeCommit: (RestorePlan) -> Step   /* .go | .again | .stop */,
               newVault:) -> Outcome   /* .committed(RestorePlan) | .lockedAfterWrite | .stopped
                                          | .failed(Error) | .keptChanging */
```

Restore passes the rollback copy as `beforeCommit`; the import passes the comparison with the
numbers the user confirmed (rev. 4, "Plan"). Restore's behaviour does not change; D-11 lists the
tests that pin it.

The import's plan is `RestorePlan.make(mode: .merge, payload: Backup.Payload(history:, templates:,
settings: nil), currentHistory:, currentTemplates:, currentSettings: settings,
restorePreferences: false, folderName:)`. What the code as it is does with that, said here so
nobody has to rediscover it:

- `commit` writes all three files; `settings.json` is rewritten with the settings in force (the
  plan carries them unchanged). The import never changes a setting.
- Merge appends — `candidate = currentHistory + added` — and `HistoryStore.trimmed` keeps from the
  front. Imported items therefore sit **after** everything already in the history, whatever their
  dates, and are the first to be left out by a ring, an age or a byte limit; an import never pushes
  a current item out. The adapter hands the items over newest first (the source's last-copied
  date), so their own order is kept. The preview says *added after your current history*.
- `history.publish` validates and de-duplicates ids once more; the adapter has already given every
  item a fresh `UUID` and Keepit's own `contentHash`.
- The import never creates a vault (`newVault`), never writes a rollback copy (Merge adds), never
  sets a file aside.

### D-2 · When the import is refused

One entry function, `importFrom(_:)` (`ImportActions.swift`), serves every row of the pane and
*Choose file or folder…*; there is no other entry (D-10). Before anything is read it refuses:

| State | Check | What the user gets |
|---|---|---|
| locked | `isLocked` | a beep (the lock has closed the Settings window anyway) |
| a data file Keepit could not read — `history.json`, `templates.json`, or `settings.json` (safe mode, `Settings.whileUnreadable`) | `refuseWhileUnreadable()` | the existing refusal: a Merge into data that is not in memory would pass the import off as the whole (SEC10) |
| an undo that did not finish | `refuseWhileJournalArmed()` (the first line of the check above) | the existing refusal |
| a restore or another import under way | `restoreInProgress` | nothing starts. The import sets the flag for its whole flow, so keepit:// URLs and opened files (`openPendingURLs`) and the Touch ID auto-unlock wait as they do for a restore |

The first three are checked again **after every dialog and panel** of the flow — the open panel,
the progress panel, the preview — together with the lock generation (`lockCount` as it was at the
click), and once more by `commit` itself, which throws for a Merge over unreadable data and for an
armed journal whatever its caller did. A check before a dialog says nothing about the moment after
it (3.0.6 candidate review, *Save to Archive…*).

### D-3 · Limits are the 3.0.7 limits

- **History.** The plan trims with `HistoryStore.trimmed`, which since 3.0.7 first drops any item
  that fails `fitsAlone` (raw bytes over the user's `maxHistoryBytes`, or `serializedEstimate` over
  `Limits.historyFileBudget`), then applies the two rings, the age and the byte limit, then the
  file budget by `serializedEstimate` — a proven upper bound of the JSON. `historyDropped` in the
  preview is therefore the number the commit produces; the import invents no second bound.
- **Templates** are never trimmed, and favourites' copies keep their images. The plan checks count
  and depth (`Failure.templateLimit`). The **size** of `templates.json` is checked at the preview by
  encoding the plan's tree with `Storage.encoder` and comparing bytes + `Vault.sealOverhead` (when
  a key is in memory) with `Limits.dataFileMaxBytes` — the comparison `RestoreCommit.stepOverLimit`
  makes, not an estimate of it. Over the limit the preview refuses, in words about templates.
  `stepOverLimit` and the sealed-size check in `Storage.writeNow` stay behind it.
- **Per item**, the validator's ceilings as in rev. 4: `Backup.validate(item:)`, the boundary every
  store mutator applies since 3.0.5. An item that fails is left out and counted under *could not be
  read*; nothing is repaired by guesswork.
- The job's own budgets (rows, files, bytes copied, bytes decoded) are rev. 4's, two of them
  tightened (D-5).

### D-4 · With *Save history* off

Since 3.0.7 the switch means the file does not exist: `commit` passes `historyJSON: nil`, the step
removes `history.json`, and a lock purges the history. Imported history then lives until Keepit
quits or is locked — true to the setting, and easy to take for an import that failed. So the
preview says *History is not saved on this Mac (Settings → General). Imported history stays until
Keepit quits or is locked; templates are saved.*, and in that state the *History* checkbox starts
**off** (proposed — Andrey decides; the user can tick it). The result and the
locked-during-commit message follow D-7.

### D-5 · The job that reads

Reading and converting run in an `ImportJob` on **its own serial queue**, never on
`Storage.ioQueue`: `Storage.key`'s setter and every checked write wait on that queue, so a long
read there would hold up a lock, or a save, for as long as it takes. The job has no reference to
the stores, the settings or the key. Its input is a source description and budgets; its output an
`ImportPayload` and the adapted `ClipItem`s and template tree — the adapter is pure and runs here
too, as `FileImport.clip` already does for the Viewer. The result comes back with
`RunLoop.main.perform(inModes:)` and is accepted only while the flow's wait is still active and the
lock generation is the one the flow started in: the rule of `sealAndWriteOffMain`.

**Cancel.** One flag, set by the Cancel button, by a lock (D-6) and by quit; read between files,
between rows, between zip entries and, inside SQLite, from `sqlite3_progress_handler`, which also
enforces the time budget. The one-call parsers cannot be interrupted, so their inputs are capped
lower than rev. 4's general 512 MB: **Raycast JSON ≤ 64 MB, Flycut plist ≤ 64 MB, `.alfredsnippets`
≤ 64 MB as a file** (YAML stays ≤ 8 MB). A cancelled job returns nothing and removes its temp
directory before it ends.

**The temp copy** (the SQLite sets, Alfred's image directory):

- *Where.* `import-tmp-<8 hex>/` under the app's caches directory (`~/Library/Caches/com.it.keep/`;
  inside the container in the sandboxed build), as rev. 4 said — not the data folder: this is
  another program's plain data, it should not sit beside sealed files, and a caches folder is what
  the system and backup tools treat as disposable. Created `0700` by a `mkdir` that fails if the name exists. The root is a
  parameter, so tests work in a folder of their own.
- *How.* Each file is **streamed** — descriptor to descriptor, 1 MiB at a time, counted against the
  per-file and whole-job budgets as it goes — into a destination opened
  `O_WRONLY|O_CREAT|O_EXCL|O_NOFOLLOW` with mode `0600` from its first byte. Not
  `Storage.writeAtomically`: that takes the whole file as `Data`, and atomic replacement buys
  nothing in a private directory nobody else reads. What carries over from 3.0.7 is the mode rule.
- *From what.* Sources are opened **relative to the descriptor of the folder** the user or the known
  path names (`openat`, `O_RDONLY|O_NOFOLLOW|O_NONBLOCK`), then `fstat`: regular files only — the
  pattern `BackupEngine.verify` uses since 3.0.7. A symlink, FIFO or device *inside* the folder is
  neither followed nor read; it is counted in the notes. (The folder itself may be reached through
  an alias, as a file chosen in the Viewer may.) The same holds for the walk of Espanso's `match/`
  and of Alfred's image directory: depth ≤ 8, no symlinked directories. This is what makes "only
  the file or folder you point it at" true.
- *Under what names.* The database set gets Keepit's own names in the temp directory
  (`db.sqlite`, `db.sqlite-wal`, `db.sqlite-shm`), never the source's. A name that comes from the
  source — a file of Alfred's image directory, and above all a name read *out of a database*
  (Alfred's `dataHash`) — is used only if it is a single path component from a fixed alphabet
  (`[A-Za-z0-9._-]`, not `.` or `..`), and is then opened in the **copy** with `openat` and
  `O_NOFOLLOW`. A row whose name fails that has no image; it never becomes a path.
- The size and modification time rev. 4 compares before and after are taken with `fstat` on the
  descriptor the bytes are read from, not by path. Rev. 4 gave that check one message, about the
  owner having been started; a change with no launch observed gets its own (F-3) — an alert says
  only what is true on the path that shows it.
- "Complete set" (rev. 4, point 2) means: each of `.sqlite`, `-wal`, `-shm` that exists at the first
  listing is in the copy. After a clean quit there may be no `-wal`; that is normal. A `-wal` that
  is in the source and not in the copy — a single file chosen where the folder was needed — is the
  error.
- *How long.* Removed by the job when it finishes, fails or is cancelled (`applicationWillTerminate`
  cancels and waits for it, bounded). Leftovers of a killed process are removed at launch, at the
  next import, by Reset, and by uninstall (which already removes the caches folder). A leftover
  that cannot be removed is reported once per launch through the same deferred report as an
  unswept journal — plain data left behind is said, not assumed gone — and never stops the launch.

**SQLite, as an untrusted file.** A database in another program's folder, or in any folder the user
points at, is input. The system library (`import SQLite3`; no new dependency) opens the *copy*
read-only, and before the first query of ours: trusted schema off, triggers and views disabled
(`SQLITE_DBCONFIG_TRUSTED_SCHEMA`, `…_ENABLE_TRIGGER`, `…_ENABLE_VIEW` set to 0), `PRAGMA
cell_size_check=ON`, `PRAGMA mmap_size=0`, and `PRAGMA quick_check` with any reported error
refusing the file `[doc: https://www.sqlite.org/security.html §1.2, 14 Nov 2026]`; `sqlite3_limit`
for value length (the image ceiling) and column count; the progress handler above. Only fixed,
prepared statements. The tables and columns a reader expects are compared with `PRAGMA table_info`
first, and a layout that is not the fixture's is *this version is not recognised* — nothing is
guessed. No extension loading, no `ATTACH`. Each option is checked at the PR against the library of
the deployment target (macOS 13).

**Zip (`.alfredsnippets`).** Foundation has no reader and Keepit starts no process. A small reader
of its own in `KeepitCore/Import`: central directory only; methods 0 (stored) and 8 (deflate,
through the Compression framework's raw-DEFLATE decoder, already linked for LZFSE); no zip64, no
encryption, no multi-disk; every entry inflated into a bounded buffer and refused when the count
passes the declared size or the per-entry ceiling; the limits and name rules of rev. 4's table. Its
tests are the hostile archives: a bomb, overlapping entries, a size that lies, `../` names, a
symlink entry.

**YAML.** As in rev. 4 (C-1), with one thing to settle in the gate prototype: if the bounded event
pass is enough to build the espanso DTOs directly, Yams is not added at all — one vendored C
library instead of a Swift package on top of it. Either way the dependency changes `Package.swift`
and `Package.resolved`; `Scripts/check_resolved.sh` and the App Store variant
(`KEEPIT_APPSTORE=1`) are part of that PR's checks.

### D-6 · What a lock does to an import

A lock can arrive at any point of the flow — the hot key is delivered into modal loops, the
screen-lock delay fires on its own. `lock()` already begins with `AbortableModal.abortIfRunning()`
and closes the Settings window.

| Where the flow is | On a lock |
|---|---|
| open panel (*Choose…*) | the panel is the system's and shows nothing of Keepit's: it stays, as Restore's does. Its answer is discarded by the generation check before anything is read |
| progress panel (copy, parse, adapt) | run through `AbortableModal` (a window entry beside the alert one): it closes, the job is cancelled, a result that still arrives is dropped by the generation check, and the temp copy goes at the job's next cancel point |
| preview — numbers, checkboxes, the list of what needs attention (it shows snippet names) | abortable: it closes, and the payload is released with the flow's frame |
| lock → unlock while a dialog was up | the answer belongs to the old generation and is discarded, as for a template prompt since 3.0.4 |
| commit stage, before the files | `lockCount` at the top of every round: stop, nothing written |
| commit stage, after the files, before the stores are published | `lockedAfterWrite`: the files hold the import, the stores stay purged and load them at the unlock (with *Save history* off: D-4, D-7) |
| result (it lists names) | abortable |

What a lock does **not** do: it does not wait for the job (the job holds no key and no store), and
it does not wipe the job's buffers — they are released, like a store's items on `purge()`; no
stronger claim is made. The temp copy holds nothing that is not also in the source program's own
folder, in plain, on the same disk.

Nothing is reported after the unlock about an import a lock cancelled before its commit: nothing
changed and nothing was promised.

### D-7 · Every text true on every path

The commit's errors are worded for Restore: *Restore cancelled…*, *…the restored data is on disk*,
*Lower the limits in Settings → History first*, *…undoing an interrupted restore*. The import maps
each `RestoreCommit.Failure` to a text of its own (the failure table names them). Three texts
describe shared *state* and are shown later by code that cannot know which flow left it; they
become neutral — new keys, the old ones stay in the tables unused, they were never false:

- `RestoreCommit.Failure.journalArmed` — *An earlier restore could not be undone completely…* →
  *An earlier change to Keepit's data…*;
- `stopForUnfinishedUndo`'s alert — the same;
- the launch-time message for a replay that failed.

`lockedAfterWrite`: *the imported data is on disk and is loaded when you unlock* is false for the
history when *Save history* is off. Two texts, chosen by `plan.settings.historySave` and by what
the plan added. **The same holds for Restore today**: `restore(from:)` says *The restored data is
on disk and is loaded when you unlock* after a commit that has just removed `history.json` because
the settings in force have saving off — the restored history went with the lock. Found while
writing this section; fixed in the stage-3 PR with its test (a P3 in the shipped 3.0.7, not
something the import introduces).

### D-8 · Reading another program's folder: what macOS allows

New since rev. 4, and the reason one detail of "Detect and privacy" changes. Keepit's direct build
is not sandboxed, but two wave-1 sources live inside *another developer team's sandbox container*:
Maccy (`~/Library/Containers/org.p0deje.Maccy/…`) and the App Store build of Flycut. macOS protects
those from other teams' processes:

| macOS | A process of another team opens a file in such a container |
|---|---|
| 14 – 26 | the system asks: *"…" would like to access data from other apps* `[observed: https://developer.apple.com/forums/thread/742147 and users' reports]` |
| 27 | no question: refused by default; the user manages it in System Settings → Privacy & Security `[doc: macOS 27 release notes, System Integrity Protection, as quoted at https://mjtsai.com/blog/?p=52154, 9 Jun 2026 — to be re-read at developer.apple.com at stage 2]` |

Alfred (`~/Library/Application Support/Alfred`), Espanso (`~/Library/Application Support/espanso`)
and the direct build of Flycut (`~/Library/Preferences`) are not containers. Raycast's and Alfred's
snippets are exports the user saves where they like.

Rules that follow:

1. **Opening the pane touches no container.** For a container source `detect()` asks only whether
   the program is installed (`NSWorkspace.urlForApplication(withBundleIdentifier:)`); the row says
   *Installed*, and the container is opened for the first time when *Import…* is clicked. A system
   question, where the OS has one, then answers a click the user has just made — Keepit never causes
   one by being looked at. (Rev. 4 checked the path for every row.)
2. **A refusal is not "not found".** `EPERM`/`EACCES` at the click → the row and the sheet say that
   macOS did not let Keepit read that program's folder, and offer the ways that need no special
   right: *Choose folder…*, and — always available — copying the folder somewhere else in the Finder
   and choosing the copy.
3. **Keepit never asks for Full Disk Access**, and no text suggests it.
4. Whether a folder chosen in the open panel is readable when it lies inside another team's
   container differs by OS version and is **not known** for 27: `[observed: pending]`. Until it is
   observed, the guide describes only the Finder-copy route for Maccy on macOS 27.

Observation matrix (Andrey, with the fixtures and again with the first build that has the Maccy
reader): macOS version × {direct build, App Store build} × {known path at the click, open panel on
the container folder, a Finder copy} → asked / refused / read. The Maccy reader's PR is not final
until its row is filled.

### D-9 · The converter mirrors the engine's limits

The engine changes rev. 4 called stage 1 shipped in 3.0.5 (PR #30): `Snippets.pasteRoute`, named
date styles, shifts on `time`/`datetime`, several shifts per token; `SnippetRouteTests` holds the
route table. The engine also has limits now, and a converted token must respect them or Keepit
would paste something *other* than the source meant, without a word:

| Engine rule (3.0.7) | Converter |
|---|---|
| a token name starts with ASCII a–z; `{INPUT:x}` is text | emits lowercase names only |
| ≤ 4 shifts in a token, each ≤ 4 digits (`snippetShiftsMax`, `snippetShiftMaxDigits`); otherwise the token stays text | a source token outside that → the **source** token literal + attention |
| a date pattern ≤ 200 characters | longer → literal + attention |
| ≤ 20 questions per template; later ones take their default unasked | a snippet with more → the whole snippet literal + attention |
| ≤ 50 choices; the rest are dropped | more → literal + attention |
| `{random:lo-hi}`, both 0…999 999 999; anything else behaves as `0-9` | outside → literal + attention |
| `{clipboard:N}`, N of at most 6 digits | larger → literal + attention |
| an expansion never grows past one text item | nothing to convert: the engine truncates and says so |

One property test ties them together: every template the converter emits goes through
`Snippets.pasteRoute` and is expanded with a fixed context; each token the converter meant as a
token must have been evaluated (nothing it emitted as `{name…}` is left in the output as text), and
each literal must come back as the source's bytes.

### D-10 · What does not change

- **Entries**: the pane's rows and *Choose file or folder…*. No keepit:// command (the list of
  eleven stays), no document type in `Info.plist` (a double-clicked `.alfredsnippets` does not open
  Keepit), no drag target, no offer at first launch, nothing in the background.
- **Entitlements**: none added. The sandboxed build reads through the open panel's security scope
  (`com.apple.security.files.user-selected.read-write` is there for the Viewer); still no network
  entitlement.
- **Format**: imported items are ordinary items that passed the validator. A backup written after
  an import must open in 3.0.5–3.0.7; the candidate review repeats 3.0.7's interop check with the
  real tag-3.0.7 reader. `minReader` stays 3.0.
- **Pane**: *Import* after *Backup*, before *Advanced* (the list is now General, Shortcuts, Paste
  Queue, History, Menu, Security, Backup, Advanced).
- **Strings**: `Scripts/add_strings.py` with all 20 translations. `en.lproj` still carries three
  2.x keys nothing references — `Import…`, `Import Backup`, `Import finished — history: %d item(s),
  templates: %d item(s).` — among the 24 unused keys waiting for removal. The pane reuses `Import…`
  (the button's translations exist), so the clean-up PR keeps that key, or runs after stage 4.
- **Fixtures** live under `Tests/KeepitTests/Fixtures/import/<program>/` (`Package.swift` excludes
  `Fixtures`; tests open them by path).

### D-11 · Existing tests that pin what these stages touch

| Change | Pinned by |
|---|---|
| `RestorePlan.make`: no folder for an empty template payload; the new counts | `RestorePlanTests` (seven Merge cases; `templatesAdded` in `testMergeDropsImportedHotKeysReplaceKeepsThem`), `LoadResultAuditTests` (one Merge) |
| the commit stage extracted from `restore(from:)` | the callers of `commit` and of the armed-journal paths: `CandidateAuditTests`, `ModalLifecycleTests`, `HeldFileFollowupAuditTests`, `LoadResultAuditTests`, `ProtectionRoundTwoAuditTests`, `ProtectionRoundThreeAuditTests`, `Sec10RoundThreeTests`, `Sec10RoundFourAuditTests`, `Sec10RoundSevenAuditTests`, `ProtectionCommitTests` |
| neutral journal texts | `LocalizationTests` (equal key counts in the 21 tables) and any test that matches the old text |
| a window entry in `AbortableModal` | `ModalLifecycleTests` (`testOrdinaryChildOverAWrappedParentIsNotAborted`), `LockSurfacesTests` |
| a new pane | `LayoutTests` (every pane stays inside the window) |

### Decisions of rev. 4 that rev. 5 changes

1. `detect()` does not look inside another team's container (D-8).
2. Inputs of the one-call parsers are capped at 64 MB, not 512 MB (D-5).
3. The temp copy is streamed, its sources opened `O_NOFOLLOW` relative to the folder; a symlink
   inside a folder is not followed (D-5).
4. With *Save history* off the *History* checkbox starts off and the preview says why (D-4).
5. Stage 1 is done; stage 2 is an infrastructure PR, then one PR per reader (Stages).

Everything else stands as accepted.

## Failure table

Every row is a test at the stage named. "Disk" is Keepit's data folder.

| # | Failure or interruption | Disk | Memory | The user sees | Stage |
|---|---|---|---|---|---|
| F-1 | at the click: Keepit locked, data unreadable, safe mode, a journal armed, a restore or import under way | unchanged | unchanged | D-2 | 3 |
| F-2 | the owner program is running at the binding check (SQLite sources) | unchanged; nothing read | — | *Quit Maccy, then import* | 2 |
| F-3 | the owner is launched, or a source file's size or date moves, during the copy | unchanged; temp copy removed | result discarded | launch observed: *Maccy was started while Keepit was reading its history — quit it and try again*; a change without a launch: *Maccy's files changed while Keepit was reading them — make sure Maccy is closed and try again* | 2 |
| F-4 | macOS refuses the folder (container protection, permissions) | unchanged | — | D-8 rule 2; never "not found" | 2, 4 |
| F-5 | a source over a budget — size, files, rows, time; a zip bomb; the YAML preflight | unchanged; temp removed | — | which limit, and that nothing was imported | 2 |
| F-6 | a symlink, FIFO or device in the folder; a `..`, absolute or symlink entry in a zip | unchanged | — | folder: the entry is skipped and counted; zip: the archive is refused | 2 |
| F-7 | the database fails `quick_check`; or its tables are not the fixture's layout | unchanged | — | damaged: *<Program>'s database is damaged or incomplete; nothing was imported*; another layout: *Keepit does not recognise this version of <Program>'s data* — never a partial import | 2 |
| F-8 | an item fails the validator (text not UTF-8, an image that does not decode or is over the pixel ceiling, over a size ceiling) | — | the item is left out | counted in the preview under *could not be read* | 2, 3 |
| F-9 | the temp directory cannot be created; the disk fills during the copy | unchanged; partial temp removed | — | the error; nothing imported | 2 |
| F-10 | Cancel on the progress panel | unchanged; temp removed at the next cancel point | result discarded | the pane, as before | 4 |
| F-11 | a lock during the open panel, the progress panel, the preview or the result | unchanged | payload released (D-6) | nothing after the unlock | 4 |
| F-12 | lock → unlock while a dialog was up | unchanged | the answer is discarded (generation) | nothing | 4 |
| F-13 | nothing new — all duplicates, both boxes off, an empty source | unchanged; no commit | unchanged | *Nothing to import* | 3 |
| F-14 | the template tree would pass the count or the depth | unchanged | unchanged | the existing limit text | 3 |
| F-15 | `templates.json` would pass the file limit | unchanged | unchanged | the preview refuses, in words about templates (D-3) | 3 |
| F-16 | the stores changed between preview and commit and the numbers got worse | unchanged | unchanged | the preview again with the new numbers; after three rounds *the data kept changing* | 3 |
| F-17 | commit: a previous file unreadable or held, the journal cannot be written, a write fails and the undo succeeds | as before the import | unchanged | *Could not save the imported data: … — the previous files were kept* | 3 |
| F-18 | commit: a write fails and the undo does not finish (journal armed) | mixed; the journal is the intact copy | files pinned before the alert | the neutral unfinished-undo text; Keepit quits without saving (`exit(1)`); the next launch replays | 3 |
| F-19 | the process is killed between the three writes | journal armed | — | the next launch replays before anything is read: the import did not happen; temp leftovers swept | 3 |
| F-20 | committed; a lock before the stores are published | the import is in the files (history only when saving is on) | stores purged | after the lock: one of D-7's two texts | 3 |
| F-21 | committed; the journal's copies cannot be removed | the commit stands | published | the existing deferred report (`unsweptToReport`) | 3 |
| F-22 | quit, logout or an update's relaunch during the job | unchanged; temp removed by the quit, else at the next launch | — | — | 2, 4 |
| F-23 | a leftover `import-tmp-*` cannot be removed at launch | a plain copy is still in the caches folder | — | reported once per launch; the launch goes on | 2 |
| F-24 | *Save history* is off | no `history.json`, as the setting says; templates saved | history until quit or lock | D-4 before, D-7 after | 3, 4 |


## Stages and the audit

0. This document (rev. 5) → auditor. No code before "no further findings".
1. ~~Engine changes~~ — shipped in 3.0.5 (PR #30): `Snippets.pasteRoute`, date styles, shifts on
   time/datetime, several shifts per token.
2. `KeepitCore/Import`, in this order:
   - **2a — infrastructure**, with no knowledge of any format: the models, the `Importer` protocol,
     budgets and the cancel flag, the temp directory and the streamed `O_NOFOLLOW` copy, the SQLite
     wrapper with the untrusted-file settings, the zip reader (D-5). Needs no fixture; its tests
     are the hostile inputs.
   - **2b — one PR per reader**, each against its verified fixture, in the order the fixtures
     arrive (expected: Maccy, Flycut, Raycast, Alfred history, Alfred snippets; Espanso last, after
     the YAML-preflight gate).
   - **2c — the placeholder converter**, a pure function with the table tests and D-9's property
     test; after the first snippet fixture.
3. Adapter + `RestorePlan` changes + the commit stage extracted (D-1) + the import's own error
   texts and the neutral journal texts (D-7, with the Restore text found there);
   `RestorePlanTests` for the empty folder and the counts; journal-interruption tests reused.
4. Pane, progress panel, preview, result (D-6); guide chapter — English and the nine site
   translations in the same PR; privacy policy sentence (all three copies); screenshots; CHANGELOG;
   D-8's matrix filled.
5. Whole-tree review of the candidate; manual acceptance of the direct build **and** of the App
   Store build (the sandboxed route is a path of its own); the release diff to the auditor; release.
6. Wave 2, one PR per program.

Each stage: the self-review written into the brief, draft PR, the auditor's findings become tests,
the next stage only after "no further findings".

## Fixture checklist (Andrey)

Made in a **separate macOS user** (`fixtures`): the programs' stores are per user and start empty
there, so nothing real can end up in a file that goes into a public repository.

**History managers** (Maccy, Flycut, Alfred) — the same set, copied in this order: `Keepit fixture
one`; three lines of text; `Привет, мир 👋 — 日本語`; `https://keep.it.com/guide`; a screenshot to
the clipboard; a file `fixture.txt` copied in the Finder; **Bold fixture** copied from TextEdit
(RTF); `{not a token} {{x}}`. Then pin or favourite the first item where the program can.

**Snippet managers** (Alfred, Raycast, Espanso) — placeholders inserted with the program's own
menu, so the file holds its real syntax:

| Name | Keyword | Content |
|---|---|---|
| `fx plain` | `fxp` | `Plain fixture snippet` |
| `fx dynamic` | `fxd` | date + clipboard + cursor |
| `fx input` | `fxi` | an input field, where the program has one |
| `fx braces` | `fxb` | `{not a token} {{x}}` |
| `fx nested` | `fxn` | inserts `fx plain`, where the program can |
| `fx outside` | `fxo` | any text |

The first five in a folder or collection `Fixture`, the sixth outside it.

Then, with the program **quit**:

- Maccy: the `Maccy/` folder (sqlite + wal + shm) zipped; Maccy's version (About).
- Alfred: the `Databases/` folder zipped (clipboard.alfdb + sidecars + image files) and the
  `.alfredsnippets` export of the collection; Alfred's version.
- Raycast: the exported JSON; Raycast's version.
- Flycut: `com.generalarcade.flycut.plist`; version.
- Espanso: the `match/` folder; `espanso --version`.
- Wave 2 when at hand: Clipy XML, TextExpander and aText exports, CLCL `history.dat` + `regist.dat`.

Archives are named with the version (`maccy-2.3.0.zip`). With them, for D-8's matrix: the macOS
version, and what happened when Terminal read Maccy's folder — a question from the system,
"Operation not permitted", or nothing.

Every fixture is grepped/OCR'd for anything real before it is committed, and its row in the tables
above gets the path, sha256 and program version.
