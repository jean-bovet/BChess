# APP-7 — Game export (iOS)

Revision 4 (2026-10-24).

- Revision 1: initial plan.
- Revision 2: Codex plan round 1 (3 SHOULD-FIX, 1 SIMPLER, all accepted): a re-import test through `GameShell.importFile`; a partial-failure test; exporting into the library's own folder is refused (`ExportError.libraryFolder`), tested; the chosen format lives only in `FilePicker.exportFolder`.
- Revision 3: Codex plan round 2 (1 BLOCKER, 2 SHOULD-FIX, all accepted): every export-all write goes through one `NSFileCoordinator` write per file; the picker's mode is non-optional state that dismissal cannot clear, with a `Bool` driving presentation (as Import does today); a narrow "Games list · Small iPhone" gallery scenario.
- Revision 4: Codex plan round 3 (1 BLOCKER, 1 SHOULD-FIX, both accepted; last round): each write is an exclusive create (`.withoutOverwriting`) inside the coordinated accessor, moving to the next " N" name when the file exists; the export's bytes are snapshotted on the main actor and the coordinated writes run off it (`@concurrent`), awaited; tests for the race, the off-main write, read-before-write and a mid-export write failure.
- r4 post-implementation (Codex code round 1): the project does not enable `NonisolatedNonsendingByDefault`, so a `nonisolated` async function already leaves the caller's actor and `@concurrent` is an explicit statement of that, not what makes `exportAllWritesOffTheMainActor` pass; the test is proven red against a real regression (the writer as `nonisolated(nonsending)`, which runs on the caller's main actor). `exportAllNeverOverwritesAFileCreatedDuringExport` is proven red with `.atomic`.

Jean's request (scope already chosen): on iPhone and iPad,

1. export a game from the games list, not only the open game;
2. offer the BChess format (`.bchess`, `GameState` JSON) as well as `.pgn`, PGN first (for other
   chess apps);
3. export all games at once: every game written as its own file into a folder the user picks in
   Files (iCloud Drive or elsewhere);
4. rename the More menu's "Share Game" to "Export", and put Export next to Import in the games list
   toolbar.

iCloud sync of the library is out of scope. The Mac is out of scope (see "Mac" below).

## 1. Problem, with evidence

- **Only the open game can leave the app, and only as PGN.** `PGNExport: Transferable`
  (`iOS/GameRootView.swift:13-23`) has one `DataRepresentation(exportedContentType: .pgn)`; its one
  caller is the More menu's `ShareLink` "Share Game" (`iOS/GameRootView.swift:203-206`), built from
  `shell.session.gameState.pgn` and `shell.current.title`.
- **PGN loses what BChess knows.** `GameState.data(for: .pgn)` writes the raw `pgn` string only
  (`Shared/Model/GameState.swift:154-158`); reading it back gives `white: .human, black: .human`
  and `rotated: false` (`GameState(data:contentType:)` case `.pgn`, `GameState.swift:134-135`). So a
  game against the Club computer, exported and imported again, becomes a two-human game seen from
  White. `.bchess` round-trips `pgn`, `rotated`, `white`, `black` (`GameState.swift:116-122`,
  `data(for: .bchessGame)`, `GameState.swift:146-151`).
- **The games list has no export.** Rows (`GamesList.row(_:in:)`, `iOS/GameRootView.swift:275-308`)
  are a `Button` that opens the game; the only other gesture is `.onDelete` (`:318-320`). The
  toolbar has `Button("Import")` (`:363`) and a `.fileImporter` for `[.bchessGame, .json, .pgn]`
  (`:375-382`).
- **The games live only in the app's Documents folder** (`GameLibrary.documents`,
  `Shared/Model/GameLibrary.swift:34-36`), visible in Files under On My iPhone › BChess. Getting
  every game out today means copying them one by one in Files, and the library also holds legacy
  `.json` and `.pgn` files (`GameLibrary.extensions`, `:30`), so the user sees mixed formats.

## 2. Design

The smallest correct change: two methods on `GameShell` that produce the bytes and write the
folder, a renamed `Transferable` with one representation per format, one small export menu view used
by two places, and a toolbar Export menu that drives a folder picker. All bytes come from the
existing codec `GameState.data(for:)`; nothing writes a new format.

### 2.1 Model (`Shared/Model/`, tested)

- **`ExportFormat`** (in `GameShell.swift`): `enum ExportFormat: CaseIterable, Sendable { case pgn,
  bchess }` with `contentType` (`.pgn` / `.bchessGame`, the existing `UTType`s of
  `GameState.swift:11-16`) and `fileExtension` (`"pgn"` / `"bchess"`, written out rather than read
  from `UTType.preferredFilenameExtension`, which depends on the host's Info.plist). Callers: the
  single export and the export of all games. `case pgn` is first, so menus list PGN first.
- **`GameShell.exportData(of file: GameFile, as format: ExportFormat) throws -> Data`**: the state is
  `session.gameState` when `file.url == current.url`, else `try library.open(file)`
  (`GameLibrary.open`, `GameLibrary.swift:70-75`); returns `state.data(for: format.contentType)`.
  It never saves and never touches the library file.
  *Unsaved changes:* the view saves on every change of `session.gameState`
  (`iOS/GameRootView.swift:129-131`) and on backgrounding (`:132-136`), so the file is normally
  current; when a save failed (`GameShell.saveError`), the session holds edits the file does not.
  Exporting the session's state means the export always shows what the user sees, saved or not.
- **`GameShell.exportAll(to folder: URL, as format: ExportFormat) async throws -> [URL]`**
  (`@MainActor`, like the rest of `GameShell`), in three parts:
  1. *Refuse the library's own folder* — `folder` and `library.directory`, each
     `standardizedFileURL.resolvingSymlinksInPath()`, compared by path — by throwing
     `GameShell.ExportError.libraryFolder` (`LocalizedError`: "Choose a folder outside BChess's own
     games: exporting there would list every game twice.") before reading or writing anything. The
     library lists only its top level (`GameLibrary.reload`, `contentsOfDirectory`,
     `GameLibrary.swift:60-62`), so a subfolder of Documents is a valid destination and does not
     change the list.
  2. *Snapshot on the main actor* — for each `library.games` entry, in list order (newest first),
     `ExportFile(baseName: file.title, data: try exportData(of: file, as: format))`, where
     `struct ExportFile: Sendable { let baseName: String; let data: Data }` (in `GameLibrary.swift`).
     Every game is read before any byte is written, so an unreadable game fails the export with an
     empty destination. Later edits to the open game while the writes run do not change this export
     (it is the state at the tap).
  3. *Write off the main actor* — `try await GameLibrary.writeExports(files, to: folder,
     extension: format.fileExtension)`, a **`@concurrent nonisolated static func … async throws ->
     [URL]`**. `@concurrent` states the isolation explicitly: it runs on the global concurrent
     executor whatever the module's `nonisolated` default is, so the main actor stays free while a
     slow provider coordinates. Its inputs are `Sendable` (`URL`, `String`, `[ExportFile]`, and the
     `@Sendable` test hook below); it touches no `GameLibrary` instance state. It brackets the work
     with `folder.startAccessingSecurityScopedResource()` / `stop…` (the pattern of
     `GameLibrary.importFile`, `GameLibrary.swift:112-117`; security scope is per process, so any
     thread may hold it). For each file:
     - `candidate = availableURL(in: folder, baseName:, extension:)`;
     - `beforeWrite(candidate)` — a test hook, `beforeWrite: @Sendable (URL) throws -> Void = { _ in
       }`, the only seam, used by three tests; production passes nothing;
     - **one coordinated write**: `NSFileCoordinator(filePresenter: nil).coordinate(writingItemAt:
       candidate, options: [], error: &coordinationError) { coordinated in try data.write(to:
       coordinated, options: .withoutOverwriting) }`, writing to the URL the coordinator hands back.
       `.withoutOverwriting` is an exclusive create (`O_EXCL`): if a file appeared under that name
       after `availableURL` looked — another app, the provider, a second export — the write fails
       with `CocoaError(.fileWriteFileExists)` instead of replacing it, and the loop goes back to
       `availableURL` for the next " N" name. That is what makes D3's "never overwrite" hold under
       concurrency; coordination alone serializes access but reserves no name.
     - any other error — the coordination `NSError` out-parameter, or a write error captured inside
       the block and rethrown after it — ends the export and is thrown.
     `.withoutOverwriting` cannot be combined with `.atomic`, so a write that fails midway could
     leave a partial new file (never a damaged existing one); the files are a few KB, and the
     error is reported. Accepted.
     Why one coordination per file rather than one on the picked folder: Apple's directory-access
     guidance coordinates each item the app writes inside a picked folder; per file is the same few
     lines in the loop, holds the provider for one write at a time, and leaves every finished file
     already handed to the provider. Coordination is what iCloud Drive and File Provider extensions
     need; security scope only grants access.
  Returns the written URLs. On a write error, files already written stay (the user can see them),
  later games are not written, and the library and the shell are unchanged (no library file is
  written; `reload()` is not needed, the destination is never the library's folder).
  `GameShell.exportAll` passes `beforeWrite` through (`beforeWrite: @Sendable (URL) throws -> Void
  = { _ in }`) so the tests drive it through the shell.
- **`GameLibrary.availableURL(in:baseName:extension:) -> URL`** (`nonisolated static`): the
  collision loop of `GameLibrary.create` (`GameLibrary.swift:96-103`, "Name", "Name 2", "Name 3")
  extracted so that `create` and `writeExports` share it. Two callers; `create`'s behaviour is
  unchanged (pinned by the existing `createAvoidsNameCollision`, `BChessTests/GameLibraryTests.swift:153`).
  Collisions it resolves on export: a file already in the target folder (never overwritten, D3), and
  two library games with the same title in different formats (`Game.bchess` and a legacy `Game.pgn`
  both export as `Game.pgn` → `Game.pgn`, `Game 2.pgn`).
- **File names**: `GameFile.title` (`GameLibrary.swift:23-24`), the name the list shows, plus the
  format's extension — the same name `PGNExport` suggests today.

### 2.2 Views (`iOS/GameRootView.swift`, exempt from unit tests)

- **`GameExport: Transferable`** replaces `PGNExport`: `let shell: GameShell`, `let file: GameFile`,
  `let format: ExportFormat`. Two `DataRepresentation`s (`exportedContentType: .pgn` and
  `.bchessGame`), each gated with `.exportingCondition { $0.format == … }` so an item offers exactly
  one type, each with `.suggestedFileName { $0.file.title + "." + $0.format.fileExtension }`. The
  exporting closure runs `try await MainActor.run { try export.shell.exportData(of: export.file,
  as: export.format) }` — the file is read when the user picks a destination, not while the list
  renders (a context menu's content is built with the row, so an eager read would decode every
  game on every render). `GameShell` is `@MainActor`, hence `Sendable`.
- **`ExportMenu(shell:file:)`**: a `Menu("Export", systemImage: "square.and.arrow.up")` with two
  `ShareLink`s, "PGN" (subtitle "For other chess apps") and "BChess" (subtitle "Keeps the players
  and the board side"), each with `SharePreview(file.title)`. Callers:
  - the More menu: replaces the `ShareLink` "Share Game" (`:203-206`) with
    `ExportMenu(shell: shell, file: shell.current)` — item 4's rename;
  - each games-list row: `.contextMenu { ExportMenu(shell: shell, file: file) }` on the row button
    (touch and hold) — item 1. No swipe action (D2).
  The share sheet then offers Save to Files, AirDrop, Mail and other apps, as today.
- **Export all** — in the games list toolbar, a `ToolbarItemGroup(placement: .navigationBarLeading)`
  holds `Button("Import")` and `Menu("Export") { Button("All Games as PGN"); Button("All Games as
  BChess") }`. The folder picker is the existing `.fileImporter`, made to serve both (SwiftUI
  honours only one `.fileImporter` per view), with two pieces of state:
  - `@State private var showImporter = false` — kept as today (`iOS/GameRootView.swift:255, 375`):
    the only presentation state, the one SwiftUI sets to `false` on dismissal, before the
    completion runs.
  - `@State private var pickerMode: FilePicker = .importGame` — `enum FilePicker { case importGame,
    exportFolder(ExportFormat) }`, **non-optional and never cleared**, so dismissal cannot lose it.
    "Import" sets `pickerMode = .importGame`, an Export item sets `pickerMode =
    .exportFolder(format)`, each then sets `showImporter = true`. `allowedContentTypes` is
    `[.bchessGame, .json, .pgn]` or `[.folder]` from `pickerMode`, and the completion switches on
    `pickerMode`. The format still lives only in `.exportFolder` (round 1). On cancel, `pickerMode`
    keeps its last value and is set again before the next presentation, so a stale mode never
    runs; a `.failure(CocoaError.userCancelled)`, should the completion report one, is ignored
    rather than shown in `actionError`.
  Today's Import cannot lose its operation: it has no mode, `showImporter` is a plain `Bool` and the
  completion calls `attempt(.importFile(url))` directly (`:375-382`); the design keeps that shape
  and adds only the mode. On success: `Task { do { let urls = try await
  shell.exportAll(to: url, as: format) … } catch { … } }` (the view's `Task` inherits the main
  actor; only `writeExports` leaves it); a failure goes to the existing `actionError` alert ("Couldn't export the games. …",
  like delete's "Couldn't delete this game. …", `:264`); success shows a plain alert "4 games
  exported to “Chess”" (`url.lastPathComponent`; D4). The library always holds at least the open
  game (`GameLibrary.initialGame`), so there is no empty case.
- **Footer hint** (`:340`): "Swipe left on a game to delete it, touch and hold to export it."

### 2.3 Mac

No change. The Mac app is document-based: `ChessDocument` (`Shared/ChessDocument.swift:14-35`)
declares readable `[.bchessGame, .json, .pgn]`, and `FileDocument.writableContentTypes` defaults to
those, so File › Save As / Duplicate already write `.bchess` or `.pgn`. `PGNExport` and the games
list exist only in `iOS/`. Export of all games has no Mac counterpart because the Mac has no
library (its games are wherever the user saved them).

## 3. Alternatives rejected

- **One `Transferable` offering both types, let the receiving app pick.** Files' "Save to Files"
  and most apps take the first representation they accept, silently; the user never sees a choice,
  and a chess app that accepts JSON might take `.bchess`. Jean asked for a visible choice, so each
  menu item offers one type.
- **`.fileExporter(isPresented:items:contentTypes:)` (or `documents:` with `ChessDocument`) for
  export all.** Less code, and the picker says "Move"/"Save" rather than "Open". But the names and
  collision handling are the system's: `ChessDocument.fileWrapper` sets no `preferredFilename`, so
  the `documents:` form would write "Untitled" names, and what the exporter does when "Game.pgn"
  already exists in the folder is not documented — none of it testable here. The folder picker plus
  `exportAll` keeps names and collisions in tested code. Recorded as D1 in case Jean prefers the
  system exporter's wording.
- **One multi-game PGN file for export all.** PGN allows it, and other chess apps read it, but Jean
  asked for one file per game, and BChess's own import would then show one library entry holding
  many games (`GameState.pgn` holds all games of a file, `GameSession` `pgnAllGames`).
- **Export all as a `.zip`.** Only `NSFileCoordinator`'s `.forUploading` side effect zips a folder
  on iOS, and the user then has to unzip before any app can open a game.
- **Saving before exporting the open game.** Exporting `session.gameState` gives the same bytes
  when the save succeeds and the right bytes when it failed; a save would add a failure path to
  export.
- **A swipe action for export.** See D2.

## 4. Test plan

Swift Testing, written first and failing (the methods do not exist), in
`BChessTests/GameShellTests.swift` with the existing `LibraryFixture` (`GameLibraryTests.swift:11-45`)
and `makeShell`/`playE4` helpers (`GameShellTests.swift:15-31`). The target folder is a second
`LibraryFixture`'s directory. Each test reads the exported files back through the production
reader: `GameState(data:contentType:)`, and for export all `GameLibrary(directory: target).games`
and `open(_:)`, the same reader that imports them.

- `exportPGNIsTheGamePGN` — a library `.bchess` game with Club computer Black and `rotated: true`,
  not the open one: `exportData(as: .pgn)` equals `Data(state.pgn.utf8)`; read back as `.pgn` it
  has two human players (documents why BChess is offered).
- `exportBChessRoundTripsPlayersAndRotation` — a legacy `.json` library file with `white:
  .computer(.maximum, thinkingTime: 30)`, `black: .human`, `rotated: true`: the `.bchess` export
  decodes to an equal `GameState`. Proves the export reads legacy files and keeps players, levels
  and orientation.
- `exportOfOpenGameIncludesUnsavedMove` — `playE4` on the open game without saving (no view, so no
  autosave): both formats' export contains "1. e4", and the library file still does not (export
  never saves).
- `exportAllWritesOneFilePerGame` — a library with `a.bchess`, `b.json`, `c.pgn` (three formats,
  one with a variation and a comment in its PGN): `exportAll(as: .bchess)` returns three URLs; the
  target lists exactly `a.bchess`, `b.bchess`, `c.bchess`; each opens through
  `GameLibrary(directory: target)` and equals `exportData` of its source. Repeated with `.pgn`
  (`a.pgn`, `b.pgn`, `c.pgn`; parameterized over `ExportFormat.allCases`).
- `exportAllIncludesUnsavedMoveOfOpenGame` — after `playE4` on the open game, its exported file
  contains "1. e4".
- `exportAllNeverOverwrites` — the target already holds `Game.pgn` with known bytes, the library
  holds `Game.bchess` and a legacy `Game.pgn`: after `exportAll(as: .pgn)` the old `Game.pgn` is
  byte-identical and the exports are `Game 2.pgn` and `Game 3.pgn`.
- `exportAllRefusesLibraryFolder` — `exportAll(to: library.directory, …)` and to the same folder
  spelled through a symlink (the test creates one in the target fixture) both
  `#expect(throws: GameShell.ExportError.libraryFolder)`; the library directory's file list is
  unchanged and `library.games` is the same. A subfolder of the library directory is accepted, its
  files written, and `library.games` after `reload()` is unchanged.
- `exportAllReadsEveryGameBeforeWriting` — a library of three games (newest `a`, then `b`, then
  `c`); the target already holds `x.pgn` with known bytes; after the shell is built, `b`'s file is
  removed so `library.open` fails for it. `exportAll(as: .pgn)` `#expect(throws: CocoaError.self)`;
  the target holds only `x.pgn`, with its bytes; `shell.current` and `shell.session` are unchanged.
- `exportAllWriteFailureKeepsEarlierFiles` — the same three games, all readable; `beforeWrite`
  makes the target read-only on its second call (`setReadOnly(true)`). `#expect(throws:
  CocoaError.self)`; `a.pgn` exists and opens through `GameLibrary(directory: target)` with `a`'s
  state; neither `b.pgn` nor `c.pgn` exists; the shell is unchanged.
- `exportAllNeverOverwritesAFileCreatedDuringExport` — the race, made deterministic: on its first
  call `beforeWrite(candidate)` writes known bytes to `candidate` (`a.pgn`) — after `availableURL`
  chose the name, before the coordinated write. After `exportAll(as: .pgn)`: `a.pgn` holds the
  competing bytes unchanged, `a`'s export is `a 2.pgn` (and opens with `a`'s state), and the
  returned URLs name `a 2.pgn`. Fails with `.atomic` (the competing file is replaced).
- `exportAllWritesOffTheMainActor` — `beforeWrite` records `Thread.isMainThread` into a locked box
  (a `Mutex<[Bool]>`); after the await, every entry is `false`. Fails if `writeExports` becomes
  `nonisolated(nonsending)` or main-actor and runs on the caller's (main) actor (removing `@concurrent` alone
  changes nothing in this project: see the post-implementation note). What this does not prove — that the UI stays
  responsive while a slow provider holds coordination — cannot be written as a reliable unit test
  (it would need a stalled File Provider and a timing threshold), so it is a device check (§6).
- `exportedGameReimportsWithPlayersAndRotation` — a `.bchess` library game with Club computer Black
  and `rotated: true` and a two-move PGN, exported with `exportData(as: .bchess)` and written to a
  second fixture as `Spanish.bchess`, then `shell.importFile(at:)`: the shell's `current` is a new
  library file, and `shell.session.gameState` has the same `pgn` moves, `white`, `black` and
  `rotated`; the same with `.pgn` gives the moves and two human players, `rotated: false`. This is
  the production path `GameLibrary.importFile` → `create` → `GameShell.install` → `GameSession`
  that the screen renders.
- `exportAllFailureThrows` — a read-only target (`setReadOnly(true)`):
  `#expect(throws: CocoaError.self)`, and the library is unchanged (`library.games` the same,
  `shell.current` the same).
- Existing `createAvoidsNameCollision` (`GameLibraryTests.swift:153`) stays green across the
  `availableURL` extraction.

Path from writer to screen: `GameState.data(for:)` (`GameState.swift:144`) writes; the exported
file comes back through `GameShell.importFile` → `GameLibrary.importFile` → `create` →
`GameShell.install` → `GameSession(state:)`, whose `gameState` the game screen renders
(`exportedGameReimportsWithPlayersAndRotation`); the other tests read through `GameLibrary.open`
→ `GameState(data:contentType:)` (`GameState.swift:128`), the decoder import uses. No test-only
decoder. The gallery's games-list card uses its own fixture; it shows the toolbar, not exported files.

Gallery: no new screen. The share sheet, the folder picker and the context menu are system UI, and
menus render closed in a snapshot. The existing card "Games list · Four games"
(`BChessGalleryTests/GalleryScenarios.swift:312`) changes — the Export menu beside Import and the
new footer hint — and is checked with `/preview-gallery` (`CHECK OK` and a look at that card in
light and dark). The default card is 402 points wide (`GalleryScenario.phone`,
`GalleryScenarios.swift:30`), so a new scenario covers the narrowest supported iPhone (iPhone SE,
iOS 18): `gamesListSmallPhone`, "Games list · Small iPhone", group "Games list",
`size: CGSize(width: 375, height: 667)`, the same `GamesList(shell: try gamesShell(), …)` as
`gamesListFourGames`, added to `GalleryScenarios.all`. It must show "Import", "Export", "Games"
and "Done" without truncation or overlap, in light and dark.

## 5. Invariants

- **I1 — Files keep opening: holds.** No format changes. `.bchess` export writes the same bytes as
  a library save (`data(for: .bchessGame)`, sorted keys); `.pgn` export writes the same raw PGN as
  today's "Share Game". Export only reads library files (`exportData` never saves, tested), and
  export all refuses the library's own folder (tested), so no library file is written, rewritten or
  converted, and the list never gains copies. Exported files are read back in tests through the
  import reader.
- **I2 — Search results land on their position: not at risk.** Export reads `session.gameState`
  (the persisted value) on the main actor and never starts, waits on or cancels a search; the
  share sheet's closure hops to the main actor and does no waiting on a search. Export all's file
  writes run off the main actor and only on its own snapshot, so the main thread never waits on
  them or on a search, and nothing they do touches the game.
- **I3 — Portable engine: not applicable** (no engine change).
- **I4 — UCI tool: not applicable.**
- **I5 — Private and offline: holds.** Export is user-initiated to a share sheet target or a
  folder the user picks; the app opens no connection. No new required-reason API: export writes
  files and does not read timestamps, disk space or boot time (`GameLibrary`'s existing
  modification-date reads are already declared in `Shared/PrivacyInfo.xcprivacy`).

## 6. Risks and rollout

- **File-format compatibility:** none — see I1. Old BChess versions open the `.bchess` files this
  export writes (same shape they wrote).
- **Provider destinations** (iCloud Drive, a File Provider app): the writes are coordinated and
  security-scoped. The unit tests run the coordinated code path on local scratch folders, where
  coordination succeeds trivially; that a provider accepts the files, uploads them and shows them
  without a conflict copy is **only provable on a real device** (the simulator has no signed-in
  iCloud Drive by default). Owed on an iPhone: export all to an iCloud Drive folder, to On My
  iPhone, and to a third-party provider if one is installed; twice to the same iCloud folder (names
  get " 2", no conflict copies); then the files appear on a Mac's iCloud Drive, and one of each
  format imports back with players and orientation kept for `.bchess`. Also there: whether a
  not-downloaded file in the target counts as existing for `availableURL` (iOS lists dataless iCloud
  files under their own names, so it should).
- **`ShareLink` inside `.contextMenu` and a nested `Menu`**: supported, but the lazy exporting
  closure reports a read failure only as the share sheet's own error, not through `actionError`.
  A listed game is one `reload()` already decoded, so this needs the file to vanish between
  listing and sharing. Accepted.
- **Toolbar width** on the smallest iPhone with "Import", "Export", the title and "Done": checked
  in the "Games list · Small iPhone" card; if it crowds, the two leading items become one "Files" menu (Jean decides
  then, not now).
- **One `.fileImporter`**: two modifiers on one view silently disable the first — the plan keeps
  one, its mode in a non-optional `FilePicker` that dismissal does not clear. Owed (simulator or
  device, views have no unit tests): Import a game; Export all as PGN; Export all as BChess;
  cancel the folder picker, then Import (must show game types and import, not export); cancel
  Import, then Export all (must show folders).
- **Destination = the library folder** (On My iPhone › BChess in Files): refused with a message
  (tested). A path compare is the check; a provider that hands back a different URL for the same
  folder would slip past it — owed: pick On My iPhone › BChess on a device and see the refusal.
- **Slow provider, responsiveness** (device only, see `exportAllWritesOffTheMainActor`): export all
  to an iCloud Drive folder with many games, ideally on a slow network, and scroll and play during
  the export; the UI must not freeze. A second Export all started while the first runs writes its
  own " N" names (exclusive create) — acceptable, not prevented.
- **Rollout:** iOS only, no migration, no setting. No version bump.

## 7. Decisions left open for Jean

All five decided by Jean on 2026-10-24, as recommended.

- **D1 — [Decided 2026-10-24: folder picker.] Export-all picker.** Recommended: the folder picker (Files' "Open" on a folder), with
  names and collisions in tested code. Alternative: the system exporter (`.fileExporter` with many
  items, button "Move"), system-chosen collision behaviour.
- **D2 — [Decided 2026-10-24: long-press only, no swipe.] Swipe action.** Recommended: no swipe, touch and hold only. A swipe action holds buttons,
  not a `ShareLink`, so a swipe would need its own share-sheet presenter (a `UIActivityViewController`
  wrapper: new code with no second caller), and a trailing swipe would replace the
  `.onDelete` swipe. A leading-edge "Export" swipe is possible at that cost.
- **D3 — [Decided 2026-10-24: never overwrite, add " 2".] Existing files in the target folder.** Recommended: never overwrite; add " 2", " 3"
  (exporting twice gives two copies). Alternative: replace same-named files, which makes repeated
  backups to one folder idempotent but can destroy a file the user edited there.
- **D4 — [Decided 2026-10-24: "N games exported" alert.] Success feedback for export all.** Recommended: a plain alert "4 games exported to
  “Chess”". Alternative: nothing (the user sees the files in Files).
- **D5 — [Decided 2026-10-24: PGN player-name tags out of scope.] Players in PGN (out of scope unless Jean wants it).** BChess's PGN carries no
  `[White]`/`[Black]` names from the players (`data(for: .pgn)` writes `GameState.pgn` raw). Adding
  tags would change what PGN export writes; recommended to leave it for a later plan.

## Steps

1. **Export model** — failing `GameShellTests` first (section 4), then `ExportFormat`,
   `GameShell.exportData(of:as:)`, `GameShell.exportAll(to:as:)` (async) with `ExportError.libraryFolder`,
   `ExportFile`, `GameLibrary.writeExports` (`@concurrent`, coordinated exclusive creates), and
   `GameLibrary.availableURL(in:baseName:extension:)` extracted from `create`.
2. **Export a game** — `GameExport` replaces `PGNExport`; `ExportMenu` in the More menu (replacing
   "Share Game") and in each games-list row's context menu; footer hint; gallery run.
3. **Export all games** — toolbar `Export` menu beside Import, one `.fileImporter` driven by
   `FilePicker` (import or export folder), `exportAll` with `actionError` on failure and the
   success alert; the "Games list · Small iPhone" scenario; gallery run.
