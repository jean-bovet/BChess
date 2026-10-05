# APP-2 — A simpler game screen (iPhone and Mac)

Revision 3 (2026-10-05). Codex plan review rounds 1–2 folded in; the round-2 changes are not
re-reviewed at plan stage and are covered by the phase-5 code review.

- Revision 1: initial plan, from the design Jean approved in
  [assets/APP-2-review.html](assets/APP-2-review.html) (screenshots stripped). Decisions D1–D5 in
  that page are settled and are not reopened here.
- Revision 2: Codex round 1. Analysis is now skipped only while the computer's move is actually pending, not
  on every computer turn (blocker: Back to a computer turn left "Analyzing…" forever), with a
  regression test. Variation comments are kept as tokens. Every variation move maps to its row
  for scrolling. Added a test that real analysis is dropped on position changes. Rejected: replacing
  only Copy/Paste (`CommandGroupPlacement` has no `.copy`/`.paste`, §3).
- Revision 3: Codex round 2. The move strip shows the path to the current move, which may run
  through a variation, instead of main-line rows. Added a deterministic stale-callback test across a
  mode change. The analysis expectations after a position change are split into pending reply,
  analyzable and terminal positions.

## 1. Problem, with evidence

The game screen shows 19 controls on iPhone and 14 on the Mac, several of them twice, and engine
numbers that a player cannot use.

- **Two ways to step through moves.** `GameSession.undo()`/`redo()` (`Shared/Model/GameSession.swift:255-272`)
  and `move(to:)` (`:274-298`) both move the cursor. `undo()` is exactly `move(to: .backward)` (both
  pass variation 0). `redo()` differs only at a branch point: it follows the current line, while
  `move(to: .forward)` offers the choices on the board (tested by `redoFollowsTheSelectedBranch`,
  `BChessTests/GameSessionTests.swift:124`). The iPhone bottom bar has Undo/Redo
  (`Shared/ActionsToolbar.swift:203-219`) and the panel has ◀ ▶ (`Shared/Views/NavigationActionView.swift`).
- **Rarely used actions take prime slots.** Copy & Paste has a bottom-bar slot on iPhone and a
  toolbar menu on the Mac (`ActionsToolbar.swift:185-190, 213-218`); Share is a separate top-bar
  button (`iOS/GameRootView.swift:89-94`); the Mac Board ▾ menu holds New Game, Edit Game, the game
  picker, Analyze, Practice, Flip and the info toggle (`ActionsToolbar.swift:161-184`).
- **The (i) panel mixes three things.** `InformationView` (`Shared/Views/InformationView.swift`)
  shows the PGN event name (almost always "-", `:65-68`), the opening, the move tree (`:77-83`) and
  the engine's depth, nodes and speed (`:47-61, 85-94`). Commit 26250de laid it out below the board
  on iPhone (`Shared/Views/ContentView.swift:21-27, 57-65`).
- **The engine only speaks on the computer's turn.** `session.info` is set by the computer's move
  search (`GameSession.swift:483`) and kept after its move (`:413-415`); nothing evaluates the
  position on a human's turn, so "Engine on" cannot show anything useful there.
- **Titles name files, not games.** iPhone: `navigationTitle(shell.current.title)`, the file's
  timestamp (`iOS/GameRootView.swift:81`). Mac: the document's file name.
- **Player rows are icons.** `ColorInformationView` (`Shared/Views/TopInformationView.swift:11-40`)
  shows a triangle, a cpu or person icon and "White"/"Black"; the level is not visible.
- **Mac New Game restarts in place** (`Shared/Views/NewGameView.swift:65-69` →
  `GameSession.newGame`, `:325-334`) and loses the finished game, while File › New opens a window.
  On iPhone New Game already adds a library entry (`GameShell.createGame`, `Shared/Model/GameShell.swift:69`).
- **No game-over message.** When the side to move is mated, stalemated or the position repeats,
  the screen says nothing; `ChessEngine::canPlay()` (`Shared/Engine/Engine/ChessEngine.hpp:145-155`)
  knows but only answers yes/no.

## 2. Design

The approved page is the specification for what appears where. This section settles how.

### 2.1 Overview and file map

| Area | New / changed | Deleted |
|---|---|---|
| Engine, bridge | `ChessEngine::gameEnd()`; `canPlay()` = `gameEnd() == none`; `FEngine.gameEnd` | — |
| Model (pure, tested) | `Shared/Model/GameText.swift` (titles, player labels, move labels, status line); `Shared/Model/Verdict.swift` (evaluation sentence, score, bar); `Game`/`FullMove` rows with variation tokens and a node index | `FullMove.children`, `hasChildren`, `canMergeWithNext`, `Array.add(element:)` |
| Session | engine analysis (§2.2), `isThinking`, `info` cleared on every position change | `undo()`, `redo()`, `newGame(white:black:)` |
| Shared views | `PlayerRow` (rewrites `ColorInformationView`), `StatusLine`, `EngineView`, `MoveListView`, `MoveStrip`, `NavigationButtons`; `ContentView` rebuilt | `ActionsToolbar.swift`, `NavigationActionView.swift`, `InformationView.swift`, `FullMoveView.swift`, `TopInformationView` struct, `@AppStorage("showInformationPanel")` |
| iPhone shell | `iOS/GameRootView.swift`: title, ⋯ menu, bottom bar, players sheet | Share toolbar button |
| Mac shell | `DocumentWindow` moves to `macOS/`; toolbar, title, new-document sheet; `macOS/GameCommands.swift` (Game menu, Edit routing); Settings toggle | Board ▾ and Copy & Paste ▾ menus, the in-place restart, `NewGameView.editMode` |

New Swift in `Shared/Model/` is Foundation-only, so the `BChessTests` target (which compiles
`Shared/Model`, `Game.swift`, `FullMove.swift`, `project.yml:105-117`) tests it without SwiftUI.
`xcodegen generate` is run and the project committed in every step that adds, moves or deletes a file.

### 2.2 The engine readout on the player's own turn (analysis)

The readout shows `session.info`, which from now on always belongs to the **current** position.

**When the engine is shown, the position is analyzed whenever the computer is not about to play it.**
Concretely, `GameSession` gains:

```swift
/// The engine readout is on: positions the computer is not about to play are analyzed.
var showsEngine = false { didSet { … start or stop the analysis … } }
/// The computer's move is pending: its move animation runs or its search does (the status line
/// says "thinking"). Set only on the path that ends in `requestEngineMoveIfNeeded()`.
private(set) var isThinking = false
/// An analysis search runs; `analysisID` identifies it.
private(set) var isAnalyzing = false
private(set) var analysisID = 0
```

- **The criterion is a pending computer move, not "the computer is to move".** The only path on
  which the computer plays is `play()` followed, after the animation, by
  `requestEngineMoveIfNeeded()` (`GameSession.swift:402-408, 477-481`). So `invalidate()` takes a
  parameter, `invalidate(awaitingReply: Bool = false)`; `play()` passes it through
  `contentDidChange(awaitingReply: true)`, and `invalidate` sets
  `isThinking = awaitingReply && mode.value == .play && <side to move is a computer> && engine.canPlay()`
  before it decides whether to analyze. Every other caller (navigation, `selectMove`, `load`,
  `setPlayers`, mode changes, paste) passes `false`, so a computer turn reached by Back, by
  selecting a move or by loading is analyzed like any other position — the computer does not play
  there today (`move(to:)` never requests a move, `:274-298`) and this plan does not change that.
  If the animation completion is dropped (the position changed, `perform`, `:422-432`), that change
  went through `invalidate` and reset the flag. `requestEngineMoveIfNeeded()` keeps `isThinking`
  true when it starts a search; when one of its guards returns (not play mode, human to move,
  cannot play) it sets `isThinking = false` and calls `analyzeIfNeeded()`.
- **Start** (`analyzeIfNeeded()`, private): when `showsEngine`, not `isThinking` and
  `engine.canPlay()`. It sets `isAnalyzing = true`,
  `analysisID += 1`, sets `engine.useOpeningBook = false` and `engine.ttEnabled` from the setting,
  and calls the existing `engine.evaluate(Int.max, time: Self.analysisTime)`
  (`Shared/Bridge/FEngine.mm:320`). The callback hops to the main actor and calls
  `analysisDidUpdate(info, completed:, token: id)` — the same shape as `searchDidUpdate`.
- **Where it starts**: at the end of `invalidate()` (`GameSession.swift:211`), which every position,
  player and mode change already goes through and which always runs *after* the state change in
  each caller (`load`, `contentDidChange`, `setPlayers`, `changeMode`, `analyzeReset`, `selectMove`,
  `selectGame`, `move(to:)`). And from `showsEngine`'s `didSet` when it turns on.
- **`analysisDidUpdate`** applies only when `isAnalyzing && token == analysisID`. It sets `info`,
  and on `completed` sets `isAnalyzing = false`. **It has no path to `play`**: an analysis result can
  never move a piece, whatever it holds. This is the structural half of I2 for analysis; the token
  is the other half (a result queued on the main queue for an earlier analysis, even of the same
  position, is dropped).
- **Stop**: `invalidate()` sets `isAnalyzing = false`, `info = nil` (and `isThinking` as above) before it
  bumps `positionID` and cancels the bridge (`engine.cancel()` already there). Turning
  `showsEngine` off cancels **only an analysis**: if `isAnalyzing`, it clears the flag and calls
  `engine.cancel()`; while the computer is thinking it does nothing, so hiding the readout never
  drops the computer's move. `requestEngineMoveIfNeeded()` clears `isAnalyzing` before it calls
  `evaluate`, which supersedes the analysis in the bridge (generation bump, `FEngine.mm:321`).
- **`cancelSearch()`** (used when the iOS shell replaces the session, `GameShell.swift:114`) bumps
  `positionID`, clears both flags and cancels, without going through `invalidate()`, so a session
  being thrown away never starts a new analysis.
- **Computer's turn**: `requestEngineMoveIfNeeded()` sets `isThinking = true` (it is also called
  directly by the players sheet and at launch, without `play()`) and
  `engine.useOpeningBook = true` (moved here from `init`, `GameSession.swift:96`, because the two
  searches now differ). Its progress `info` (`searchDidUpdate`, `:483`) is what the readout shows
  while the computer thinks. A completed search with no move clears `isThinking`. `play()` loses its
  `info` parameter (`:410-418`): the next position's `info` comes from its own analysis.
- **Time and CPU**: `static let analysisTime: TimeInterval = 10`, no depth cap (iterative deepening
  stops on time, `FEngine.mm:352-359`). After 10 s the last result stays on screen and the CPU is
  idle until the position changes or the engine is turned off and on. The search queue is
  `QOS_CLASS_USER_INITIATED` (`FEngine.mm:69-70`), as for the computer's move. In the background iOS
  suspends the app; when it returns the timer has expired and the search stops at its next check.
  The opening book is skipped because a book move carries no evaluation (`ChessEngine.hpp:171-181`).
- **Persistence**: `@AppStorage("showEngine")` (default `false`, D1) in `ContentView`, pushed with
  `.onChange(of: showEngine, initial: true) { session.showsEngine = $0 }`. The iOS shell recreates
  `ContentView` per game (`.id(shell.current.url)`), so a new session gets it at once. The iPhone
  Engine button and the Mac toolbar toggle and Game › Show Engine bind the same key.

Rejected: a second `FEngine` for analysis (two engines contend for CPU, and the session would have
to mirror every position change into it); analysis inside `searchDidUpdate` with a flag (one wrong
branch plays the analysis' best move — the separate method makes that impossible); `analyze:`
(`FEngine.mm:308`, unlimited time — no battery bound).

### 2.3 Evaluation words — `Verdict` (pure)

`struct Verdict: Equatable { init(centipawns: Int, isMate: Bool) }` with `sentence`, `score` and
`whiteShare` (0…1 for the bar). The value is **White's point of view**: the search returns
`score * color` (`Shared/Engine/Algorithm/MinMaxSearch.hpp:96-100`; the UCI tool flips it for the
engine's side, `BChess/UCI/FENgineInfo+Extension.swift:18-26`). The sentence names the colour
("White is slightly better"), never "you", so it reads the same for every pairing and agrees with
the sign of the score, as in every chess GUI.

| |centipawns| | sentence (for White ahead; mirrored for Black) |
|---|---|
| < 30 | "The position is equal" |
| 30 – 99 | "White is slightly better" |
| 100 – 249 | "White is better" |
| ≥ 250 | "White is winning" |
| mate (`info.mat`, `FEngineInfo.mm:48`) | "White has a forced mate" |

`score`: one decimal with a sign, "+0.4", "−1.2" (U+2212), "0.0"; mate is "Mate" (the engine reports
±`MAT_VALUE` without a distance, `ChessEvaluater.cpp:150`, so there is no "mate in N").
`whiteShare = 0.5 + clamp(cp, −600, 600) / 1200`; mate is 1 or 0.
`EngineView` builds a `Verdict` from `info.value` and `info.mat`; the best line is the existing
`info.bestLine(false)` (`FEngineInfo.mm:91`).

### 2.4 Titles, player labels, status line — `GameText` (pure)

Static functions on `enum GameText`, Foundation-only:

- `name(of player:, isWhite:, opponent:)`: the player's name when not empty; else "Computer" for a
  computer; else "You" when the opponent is a computer; else "White"/"Black".
- `title(white:black:)` = "\(name(white)) vs \(name(black))": "You vs Computer", "Computer vs You",
  "White vs Black", "Computer vs Computer", "Ann vs Computer".
- `detail(of player:, toMove:)`: "to move" for a human to move; "\(Int(thinkingTime)) s" for a
  computer (`GamePlayer.thinkingTime`, `GameSession.swift:46`); nil otherwise. The row reads
  "Computer · 5 s" / "You · to move".
- `moveLabel(number:, isWhite:, san:)`: "8. c3" / "8…O-O". Used by the status line and the variation
  tokens (§2.6).
- `status(mode:, isThinking:, gameEnd:, toMove:, lastMove:)`:
  - `.analyze` → "Analyzing. Moves are not saved."; `.train` → "Practicing openings."
  - game over → "Checkmate. White wins." / "Stalemate." / "Draw by repetition." / "Game over."
  - thinking → "Computer is thinking…" (the player's name if it has one)
  - else "Your move." for "You", otherwise "White to move." / "Ann to move."
  - followed by " Last: 8…O-O" when there is a last move.
- Subtitle = `session.openingName` (`GameSession.swift:121`), nil hides it.

**Game end** needs one bridge addition: `ChessEngine::gameEnd()` returns `none`, `checkmate`,
`stalemate`, `repetition` or `finished` (a declared result at the end of the line), with the exact
conditions of today's `canPlay()` (`ChessEngine.hpp:145-155`); `canPlay()` becomes
`gameEnd() == GameEnd::none`. `FEngine` exposes it as an `NS_ENUM` property `gameEnd`; the session
reads it as `gameEnd` (revision-tracked like the other engine-derived values). Portable C++ (I3).

### 2.5 Back and forward

Keep `move(to:)` and `canMove(to:)`; **delete `undo()` and `redo()`**. At a branch point "forward"
now offers the choices on the board, which is the ◀ ▶ behaviour the user already has and the
design's "variation arrows stay the way to pick one".

`Shared/Views/NavigationButtons.swift` — one pair used by the iPhone bottom bar and the Mac toolbar:
`Menu { Button("Start of Game") { … .start } } label: { Label("Back", systemImage: "chevron.backward") } primaryAction: { … .backward }`,
and the mirror for Forward / End of Game, `.menuIndicator(.hidden)`, disabled from `canMove(to:)`,
moves wrapped in `withAnimation`. A tap steps; touch and hold (click and hold on the Mac) opens the
one-item menu. Rejected: a `LongPressGesture` on a `Button` — in a toolbar it fights the button's own
tap and fires both. Replaces `NavigationActionView` (deleted).

Mac keyboard (§2.8): Back ←, Forward →, Start ⌘←, End ⌘→ in the Game menu.

### 2.6 Move list, strip and all-moves sheet

`Game` (`Shared/Game.swift`) keeps its name and its `rebuild(engine:)` call sites, and builds:

- `rows: [FullMove]` — the **main line** of `engine.moveNodesTree()` paired into full moves
  (`number`, `white`, `black` nodes, the existing `whiteComment`/`blackComment`), one row per move
  number. A row starting with Black ("3…a6" after a pasted FEN) has `white == nil`.
- `FullMove.variations: [[MoveToken]]` — for each alternative of the row's white then black move,
  the alternative line flattened to tokens, nested alternatives in parentheses, each move followed
  by its comment (`FEngineMoveNode.comment`, normalized with the existing `normalizeComment`), at any
  depth: `1. e4 e5 (1... c5 {Sicilian} 2. Nf3) *` gives `( 1…c5 {Sicilian} 2. Nf3 )`.
  `enum MoveToken: Equatable { case move(String, uuid: UInt), comment(String), open, close }`.
  The flattening follows the bridge's tree shape (`FEngine.mm:159-174`): a main-line node's
  `variations` are its alternatives; an alternative's `variations` are its own continuation, whose
  nodes carry their alternatives.
- `nodes: [UInt: FEngineMoveNode]` — every node by uuid, for the status line's "Last:".
- `rowIndex: [UInt: Int]` — every uuid of the tree, main line **and** every variation move at any
  depth, mapped to the index of the row it is displayed in (a variation's moves map to the row
  whose white or black move it is an alternative to). Used only to scroll the list.
- `variationCount` — alternatives in the whole game, for the strip's ⑂ mark.
- `path(to uuid:) -> [FEngineMoveNode]` — the moves from the start to that move along its own
  branch: the main line up to the move the variation replaces, then the variation (and nested
  variations) up to the move itself. Built from the same tree shape as the tokens.
- `recentMoves(current uuid:, count: 6) -> [MoveToken]` — the last six plies of `path(to:)` as
  `.move` tokens labelled for a strip ("6. Re1", "b5"; the first one "6…b5" when it is Black's);
  empty at the start. The last token is always the current move, in a variation too.

`FullMove.children`, `hasChildren`, `canMergeWithNext` and `Array.add(element:)` have no caller left
and are deleted. `FullMove` becomes a struct (it was a class only for the merge).

Views:

- `MoveListView(session:)` — the iPhone all-moves sheet, the Mac sidebar and the wide iPad layout.
  A `List` of rows: number, white move, black move in fixed-width columns (a score sheet), each a
  plain `Button` calling `session.selectMove(uuid:)`, the current move bold; comments in italics
  under the row; each variation as one wrapping `Text(AttributedString)` whose move tokens are links
  (`bchess-move://<uuid>`), handled by `.environment(\.openURL)` → `selectMove`. The current move is
  bold inside a variation too; comments inside a variation are italic in the same text. Rows are
  identified by index; on every change of `currentMoveUUID` the list scrolls to
  `game.rowIndex[uuid]` (`ScrollViewReader.scrollTo`), so selecting a move deep in a nested
  variation brings its row into view.
- `MoveStrip(session:, showAll:)` — iPhone only: `recentMoves` as one line of move buttons, then a
  trailing "All moves" button (list icon, with "⑂N" when `variationCount > 0`) that opens the sheet.
  Tapping a move jumps; the sheet is opened by its own button, so a move tap never also opens it.

### 2.7 iPhone

`ContentView(session:)` keeps the width test of 26250de (`ContentView.swift:21-27, 68-74`) and
chooses between two layouts; it no longer owns a toolbar or the players sheet:

- **Tall** (every iPhone, portrait-only since 3c0611a): `PlayerRow` (top), board, `PlayerRow`
  (bottom), `StatusLine`, `EngineView` when `showEngine`, `MoveStrip`; the all-moves sheet
  (`MoveListView` in a `NavigationStack` with Done).
- **Wide** (the Mac, iPad landscape): board column with the two `PlayerRow`s, and a 320 pt sidebar
  with the opening as heading, `MoveListView`, `StatusLine`, `EngineView` at the bottom when shown.

`PlayerRow` (renames `TopInformationView.swift`, rewrites `ColorInformationView`): a dot when that
side is to move, `GameText.name` + " · " + `GameText.detail`, then the captured pieces and the
material points as today (`TopInformationView.swift:28-37`). The `TopInformationView` struct (used
only by its previews) goes.

`EngineView(verdict:, line:, statistics:)` — value-based so previews need no engine: the sentence
and the score on one line, a thin bar (`whiteShare`), "Best: 9. h3 d5 10. exd5". `verdict == nil`
shows "Analyzing…"; hidden when the game is over. `statistics` (Mac only, §2.8) is the depth /
nodes / n/s line, formatted with the code moved out of `InformationView.speed()` (`:47-61`).

`iOS/GameRootView.swift`, `GameView`:

- **Top bar**: Games (left, unchanged); `.principal` title `GameText.title` with the opening as a
  caption underneath (`navigationSubtitle` is iOS 26-only and the target is iOS 18); a ⋯ `Menu`
  labelled "More" (right): New Game, Players & Level, Flip Board, Share Game (the existing
  `ShareLink`/`PGNExport`, `:89-94`, moved in), Copy Position (FEN), Copy Game, Paste Game or Position
  (`Pasteboard`, `Shared/Views/Pasteboard.swift`, and `session.paste`).
- **Bottom bar**: `NavigationButtons`, spacer, an "Engine" toggle button (`gauge` symbol, filled when
  on) bound to `@AppStorage("showEngine")`.
- **Players sheet**: `GameView` owns `showPlayers` and the mode; `NewGameView_iOS` titles its edit
  mode "Players & Level" (was "Settings", `NewGameView_iOS.swift:38`) and calls `onNewGame`, which
  becomes non-optional (the in-place fallback, `:55-60`, goes with `session.newGame`).

### 2.8 Mac

**Window.** `DocumentWindow` moves to `macOS/DocumentWindow.swift` (it is Mac-only and now uses
AppKit). It hosts `ContentView` and adds:

- `.navigationTitle(GameText.title(…))`, `.navigationSubtitle(opening ?? "")`.
- Toolbar: New Game, Flip Board, `NavigationButtons`, Show Engine (`Toggle`, `.toggleStyle(.button)`,
  bound to `showEngine`).
- `.focusedSceneValue(\.gameSession, showPlayers ? nil : session)` and
  `.focusedSceneValue(\.showPlayers, $showPlayers)` (`@Entry` in `FocusedValues`, macOS 15 / iOS 18).
  While the players sheet is up the Game menu is disabled (§2.9 explains why).
- The players sheet (`NewGameView`, now one mode: "Players & Level", Cancel / OK →
  `setPlayers` + `requestEngineMoveIfNeeded`, the current edit branch, `NewGameView.swift:55-60`).

**New Game (D5).** New Game in the toolbar and the Game menu calls
`NSDocumentController.shared.newDocument(nil)` — exactly File › New. A new window opens the players
sheet on its first appearance when it is a new, untitled document: `BChessUIApp` passes
`isNew: file.fileURL == nil` (`FileDocumentConfiguration.fileURL` is nil until saved), and
`DocumentWindow.onAppear` shows the sheet when `isNew && document.state == .newGame`, guarded by a
`@State` flag so it is offered once. A reopened file never shows it; a restored untitled window
with moves never shows it. Cancel keeps the default players (you vs computer). File › New keeps
⌘N; Game › New Game has no shortcut of its own, so ⌘N stays one action (the mockup prints ⌘N beside
both). `session.newGame(white:black:)` and the in-place restart are deleted.

**Menus** (`macOS/GameCommands.swift`, installed with `.commands { GameCommands() }` in
`BChessUIApp`, `Shared/BChessUIApp.swift:30-35`):

- `CommandMenu("Game")`, reading `@FocusedValue(\.gameSession)` and `@FocusedValue(\.showPlayers)`,
  every item disabled when the session is nil: New Game; Players & Level… (no shortcut — ⌘, is
  Settings, the mockup's ⌘, would collide); Flip Board ⌘R; Back ←, Forward →, Start of Game ⌘←,
  End of Game ⌘→ (`move(to:)`, disabled from `canMove(to:)`); Show Engine ⌘E (`Toggle`); Analyze
  Game and Practice Openings (`Toggle`s on `mode.value`, calling `toggleAnalyze`/`toggleTrain`, D2);
  a "Game" picker submenu only when the PGN holds more than one game (it moves here from the Board ▾
  menu, `ActionsToolbar.swift:140-150`, so multi-game PGN files stay usable).
- `CommandGroup(replacing: .pasteboard)`: Cut ⌘X, **Copy Game ⌘C**, **Copy Position ⌥⌘C**,
  **Paste Game or Position ⌘V**, Select All ⌘A.

**Settings**: `SettingsView` gains `Toggle("Show engine statistics", isOn: $showStatistics)` on
`@AppStorage("showEngineStatistics")`, default off (D3). `ContentView` passes the statistics line to
`EngineView` only on macOS and only when it is on.

### 2.9 Keeping text fields working (⌘C/⌘V and the arrows)

The only text field in a game window is the player name in the players sheet
(`NewGameView.swift:17`). Two risks, two rules:

1. **Copy, Paste, Cut, Select All are routed by the first responder.** Each Edit item first asks
   `NSApp.keyWindow?.firstResponder is NSText` (the field editor of any `TextField`). If so it
   forwards the standard selector — `NSApp.sendAction(#selector(NSText.copy(_:)), to: nil, from: nil)`
   (and `paste(_:)`, `cut(_:)`, `selectAll(_:)`) — so text editing behaves exactly as with the stock
   menu. Otherwise Copy Game / Copy Position / Paste act on the focused session, and Cut / Select
   All forward (no game meaning). The items stay enabled so forwarding always works; with no
   session and no text they forward to nothing, like the stock items. The cost: while typing a
   name the item still reads "Copy Game"; it copies the text.
2. **The bare-arrow and ⌘-arrow key equivalents are off while the sheet is up**, because the
   session is published as nil then, which disables the Game menu items.

**Verified** by the manual Mac check in §5 (owed), because there is no macOS UI-test target. If
the check shows a disabled menu item still swallowing ← in the name field, the fallback is to drop
the four arrow key equivalents from the menu and handle ←/→/⌘←/⌘→ with `.onKeyPress` on the board
of the game window; this is recorded as a deviation, not a redesign.

### 2.10 What gets deleted (no dead code)

`Shared/ActionsToolbar.swift` (every struct: its items reappear in the ⋯ menu, the Mac toolbar or
the Game menu); `Shared/Views/NavigationActionView.swift` (including the analysis reset button —
leaving Analyze/Practice from the Game menu restores the game, `GameSession.swift:372-374`);
`Shared/Views/InformationView.swift`; `Shared/Views/FullMoveView.swift`; `TopInformationView`
struct; `ContentView`'s `showInfo`, sheet state and toolbar; `GameSession.undo/redo/newGame`;
`FullMove.children/hasChildren/canMergeWithNext`, `Array.add(element:)`; `NewGameView.editMode`;
`NewGameView_iOS.onNewGame`'s optional fallback; the Share toolbar item. Step 5 ends with a grep for
each deleted symbol.

## 3. Alternatives rejected

- **Keep Undo/Redo and drop ◀ ▶** — Undo/Redo on Mac means document undo (Edit › Undo, APP-1);
  two meanings of "undo" is what the design removes.
- **Copy Game as an extra Edit item without ⌘C, stock Copy untouched** — the design asks for ⌘C;
  routing by first responder keeps text fields correct at the cost of a fixed label.
- **SwiftUI `.onCopyCommand`/`.onPasteCommand`** — they need the board to take keyboard focus (a
  focus ring and a click first) and give no ⌥⌘C item.
- **Replacing only Copy and Paste in the Edit menu, keeping the stock group** (Codex round 1,
  SIMPLER) — rejected: `CommandGroupPlacement` has no `.copy` or `.paste` placement in the macOS 26
  SDK (the Edit placements are `.undoRedo`, `.pasteboard`, `.textEditing`, `.textFormatting`;
  checked in `SwiftUI.swiftinterface`), so Copy cannot be replaced without replacing the whole
  `.pasteboard` group. Cut and Select All are therefore re-added and forwarded as in §2.9.
- **Opening name kept after the game leaves the book** — needs a bridge walk over every prefix; the
  book names only three lines anyway (`BChess/Openings.pgn`). See §7.
- **Restart in place on the Mac** — removed by D5.
- **A one-column layout on iPad landscape too** — see §7; the default reuses the Mac sidebar, so
  the wide layout is exercised on two platforms by the same code.

## 4. Test plan

Each test is written first and fails for the stated reason before its change.

**Step 1 — engine / bridge** (`BChessTests/ChessEngineTests.cpp`, GoogleTest; raise the
`registersAllCases` floor in `BChessTests/EngineGoogleTests.swift:30` to the new count)
- `GameEndCheckmate` — "1. f3 e5 2. g4 Qh4#" → `checkmate`; one step back → `none`.
- `GameEndStalemate` — a stalemate FEN → `stalemate`.
- `GameEndRepetition` — the repeated-knights PGN of `CannotPlayFromARepeatedPosition` → `repetition`.
- `GameEndDeclaredResult` — "1. e4 1-0" → `finished`; back one → `none`.
- `CanPlayMatchesGameEnd` — over the positions above, `canPlay() == (gameEnd() == none)`.
- `FEngineTests.gameEndCrossesTheBridge` (Swift) — `FEngine.gameEnd` for a mate and for the start.

**Step 2 — pure text** (`BChessTests/VerdictTests.swift`, `GameTextTests.swift`, `MoveRowsTests.swift`)
- `Verdict`: each threshold edge (0, 29/30, 99/100, 249/250, mirrored for Black), mate both ways,
  score formatting ("+0.4", "−1.2", "0.0", "Mate"), `whiteShare` at 0, ±600, ±1000 (clamped) and mate.
- `GameText.name`/`title`: you vs computer (both colours), two humans unnamed, two computers, named
  players, a name that is only spaces counts as empty.
- `GameText.detail`: human to move, human waiting, computer at each level.
- `GameText.status`: analyze, train, each game end with the winner, thinking (unnamed and named),
  your move, white/black/named to move, with and without "Last: 8…O-O" and "8. c3".
- `Game.rows`: "1. e4 e5 2. Nf3" pairs into two rows; a FEN-started game with Black first;
  comments kept; `variations` of "1. e4 e5 (1... c5 2. Nf3 (2. c3)) 2. Nf3" flattens to
  `( 1…c5 2. Nf3 ( 2. c3 ) )` with the right uuids; `variationComments` — "1. e4 e5 (1... c5
  {Sicilian} 2. Nf3 (2. c3 {Alapin})) *" keeps both comments, each right after its move, in that
  order; `nodes` holds every uuid of the tree; `rowIndex` maps c5, Nf3 and the nested c3 to the row
  of e5 and every main-line move to its own row; `variationCount`; `path(to:)` for a main-line move
  and for `3. d4` in "1. e4 e5 (1... c5 2. Nf3 d6 3. d4) *" (e4, c5, Nf3, d6, d4); `recentMoves`
  at the start (empty), in the middle, at the end, and for that `3. d4`: its last token is
  `.move("3. d4", uuid: d4)` and no main-line move after 1. e4 appears.

**Step 3 — session** (`BChessTests/GameSessionTests.swift`; the engine is real, as in the file today)
- `analysisRunsOnAHumanTurnWhenShown` — two humans, `showsEngine = true` → `isAnalyzing`, then
  `info` arrives with `depth > 0` (not a book move) and the position and the PGN are unchanged.
- `analysisNeverPlaysAMove` — a completed analysis result with a best move, fed to
  `analysisDidUpdate(…, completed: true, token: analysisID)` → no move, `isAnalyzing == false`, `info`
  set. (Red proof: route it through `searchDidUpdate` and the move is played.)
- `staleAnalysisIsIgnored` — capture `analysisID`, play e4, feed a result with the old token → `info`
  is not that result; same for a second analysis of the **same** position (toggle off/on).
- `staleAnalysisIsIgnoredAcrossAModeChange` — deterministic: engine shown, two humans; capture the
  running `analysisID`; `toggleAnalyze()` (same position, same side to move, new analysis); feed a
  real result to `analysisDidUpdate(…, completed: false, token: oldID)` and then with
  `completed: true` → `info` is never that result, and `isAnalyzing` is still true (the new
  analysis was not ended by the old completion). The real-analysis test below cannot tell the two
  apart, because the side to move is unchanged.
- `hidingTheEngineKeepsTheComputersMove` — middlegame, Black computer to move, engine shown,
  `requestEngineMoveIfNeeded()`, then `showsEngine = false` → the computer still plays within 4 s.
  (Red proof: make hiding call `engine.cancel()` unconditionally.)
- `backToAComputerTurnIsAnalyzed` (regression for the round-1 blocker) — human vs computerBlack,
  play e4, wait for the computer's reply, `move(to: .backward)` (Black, a computer, to move), then
  `showsEngine = true` → `isThinking == false`, `isAnalyzing == true` and `info` arrives; the same
  with the engine already shown before going back. (Red with the rev-1 rule "skip every computer
  turn": `isAnalyzing` stays false.)
- `realAnalysisIsDroppedOnPositionChange` — two humans, middlegame with Black to move, engine
  shown; wait for the first `info` (`isWhite == false`); then `move(to: .backward)` (White to move)
  and, separately, `paste` of a White-to-move FEN. For 1.5 s after each
  change, poll every 20 ms: `info` is nil or `info.isWhite == session.isWhiteToMove`, and a new
  `analysisID` was taken. This crosses the real bridge → main-queue hop, where a stale progress
  or completion callback would land.
- `noAnalysisWhileTheComputerIsToPlay` — after a human move against the computer, `isAnalyzing`
  stays false through the animation and `isThinking` is true; once the computer has replied,
  `isAnalyzing` is true.
- `noAnalysisWhenTheGameIsOver` — the repeated-knights position, engine shown → no analysis, `info`
  nil.
- `everyPositionChangeClearsInfo` — extends `everyPositionChangeBumpsPositionID` (`:309`), which
  uses two humans, so every position it reaches is analyzable: after each change `info == nil`
  (before any new result) and, with the engine shown, `isAnalyzing` and a new `analysisID`. The
  other two kinds of position have their own tests with the opposite expectation: a pending
  computer reply (`noAnalysisWhileTheComputerIsToPlay`: no new analysis, `isThinking`) and a
  finished game (`noAnalysisWhenTheGameIsOver`: no analysis, `info` nil).
- `cancelSearchStartsNothing` — engine shown, `cancelSearch()` → `isAnalyzing == false`, and stays
  so after a 500 ms wait.
- `analysisStopsAtItsTimeLimit` — `analysisTime` is 10 s; the test checks that `isAnalyzing` turns
  false and the last `info` stays (uses the 10 s budget once; marked `.timeLimit(.minutes(1))`).
- Changed: `undoRedo` → `backAndForward` with `move(to:)`; `redoFollowsTheSelectedBranch` →
  deleted (its forward half is `forwardAtABranchPointOffersTheChoices`, `:167`);
  `staleAnimationCompletionDoesNothing` uses `move(to:)`; `newGameResets` deleted with `newGame`;
  `computerVersusComputerContinues` stops the game with `setPlayers(.human, .human)`;
  `everyPositionChangeBumpsPositionID` loses its `newGame` line.

**Views** are exempt from unit tests (AGENTS.md); every new view gets `#Preview`s:
`PlayerRow` (to move / waiting, captures), `StatusLine`, `EngineView` (equal, slightly better,
mate, analyzing, with statistics), `MoveListView` (short game, game with nested variations and a
comment), `MoveStrip` (start, middle, with ⑂), `NavigationButtons`, `ContentView` (tall, wide,
analyze, train, rotated), Mac `DocumentWindow`, iOS `GameRootView` (exists).

**UI test** (`BChessUITests/BChessUITests.swift`, iOS scheme), updated in step 4:
`app.buttons["Actions"]` (`:20`) becomes `app.buttons["More"]`; after Black replies, tap "Back" and
expect the board value to match `".* b .* 1$"` (after 1. e4); tap "Engine" and expect an element
`engine-readout` to exist. A Mac UI test target is out of scope.

## 5. Steps (one commit each; each builds and passes every gate)

1. **Game end** — `ChessEngine::gameEnd()`, `canPlay()` on top of it, `FEngine.gameEnd`; GoogleTests
   and the bridge test. No UI.
2. **Pure text and move rows** — `Verdict`, `GameText`, `Game.rows`/`nodes`/`variationCount`/
   `path(to:)`, `recentMoves`, `rowIndex`, `MoveToken`. `InformationView`/`FullMoveView` are switched to `rows` in the same
   commit (they still exist) so the old `children` API can go. Tests first.
3. **Session analysis** — §2.2: `showsEngine`, `isThinking`, `isAnalyzing`, `analysisID`,
   `analysisDidUpdate`, `info` cleared in `invalidate()`, book per search, `gameEnd`. Tests first.
   The old panel still shows `info`; nothing visible changes yet.
4. **Shared screen and iPhone** — new views with previews, `ContentView` rebuilt (tall/wide),
   `GameRootView` top bar, ⋯ menu, bottom bar, players sheet; `undo/redo` deleted with the iPhone
   buttons; `NavigationActionView`, `InformationView`, `FullMoveView`, `TopInformationView` deleted;
   `ActionsToolbar` shrinks to its macOS branch (minus the info toggle), now attached by
   `DocumentWindow` with its sheet state, so the Mac keeps working until step 5. UI test updated
   and extended. Simulator check of the iPhone layout with the engine on (iPhone 17 Pro and the
   smallest supported iPhone).
5. **Mac** — `DocumentWindow` to `macOS/`, title/subtitle, toolbar, new-document sheet,
   `GameCommands` (Game menu, Edit routing), Settings toggle, `NewGameView` single mode;
   `ActionsToolbar.swift`, `session.newGame` and its test deleted; the dead-symbol grep. The manual
   Mac check below is run and its result recorded in the step's report.

**Manual Mac check (owed, step 5):** in Players & Level, type a name, ←/→ move the caret,
⌘A ⌘C ⌘X ⌘V edit the text; in the game window ⌘C then paste in TextEdit gives the PGN, ⌥⌘C the FEN,
⌘V of a FEN loads it; ←/→/⌘←/⌘→ step and jump; ⌘E toggles the readout; File › New and the toolbar
New Game open a window with the sheet; opening a saved file does not; window title shows the
players and the subtitle the opening. **Owed on device:** the iPhone layout with the engine on, and
touch-and-hold on Back/Forward.

## 6. Invariants

- **I1 — Files keep opening.** Holds. `GameState` and the codecs are untouched; the new settings are
  `UserDefaults` keys. `showInformationPanel` is simply no longer read.
- **I2 — A search result only lands on its position.** At risk, held by §2.2: analysis results go
  through `analysisDidUpdate`, which cannot play; each analysis has its own `analysisID`; analysis is skipped only while the computer's move is pending (`isThinking`), so it never races the move search; every
  position change clears `isAnalyzing` and `info` in `invalidate()`; hiding the engine cancels only
  an analysis; the bridge's generation guarantee (`FEngine.mm:29-37`) is unchanged. The main thread
  never waits: `evaluate` and `cancel` return at once. Tests in §4 step 3.
- **I3 — The engine stays portable.** Holds: `gameEnd()` is plain C++ in `ChessEngine.hpp`.
- **I4 — The UCI tool keeps working.** Holds: `canPlay()` keeps its result (tested by
  `CanPlayMatchesGameEnd` and the existing `CanPlay…` cases); the UCI tool sets `useOpeningBook` itself
  (`BChess/UCI/UCI.swift:31`) and does not use the session.
- **I5 — Private and offline.** Holds; nothing networked is added.

## 7. Risks and rollout

- **Mac window title.** If `DocumentGroup` on macOS 26 keeps the file name as the title despite
  `.navigationTitle`, step 5 falls back to the file name as title and "You vs Computer — Ruy Lopez"
  as subtitle, and says so.
- **Mac menu key equivalents** — §2.9 and its fallback.
- **Menus and `@Observable`.** Game menu enablement reads `canMove(to:)`; if a menu does not
  refresh after a move, the items are rebuilt from `session.revision`. Part of the manual check.
- **iPhone height.** Board, two rows, status, the engine block (3 lines) and the strip must fit
  between the bars on the smallest supported iPhone; the engine block's best line is one line,
  truncated.
- **Battery.** Bounded to 10 s of one core per position change while the engine is on (§2.2); off by
  default.
- **Behaviour change.** At a branch point the forward button offers the choices (as ◀ ▶ did); the
  old Redo silently followed the current line.
- **Opening subtitle.** `Openings.pgn` names three lines, and the name is shown only while the moves
  are in the book (`ChessEngine.hpp:159-169`). Most games will have no subtitle and no sidebar
  heading.

## 8. Decisions (Jean, 2026-10-05)

All three were decided as the defaults below.

1. **iPad in landscape** — *default:* the wide layout (board plus the Mac's sidebar) when the
   window is wider than tall, the iPhone layout otherwise; *alternative:* the iPhone layout always.
2. **Analysis time** — *default:* 10 s per position, then the result stays; *alternative:* run until
   the position changes (better lines, more battery).
3. **Opening name** — *default:* as today (only while in the book, three named lines); a richer
   opening table (ECO names) would be its own proposal.

Decided (Jean, 2026-10-05): 1. wide layout on iPad landscape; 2. 10 s, the result stays; 3. opening names left as is.
