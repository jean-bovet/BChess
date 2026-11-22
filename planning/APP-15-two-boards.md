# APP-15 — Two boards against a friend

Revision 6 (2026-11-22).

- Revision 1: initial plan.
- Revision 2: Codex plan round 1 (1 blocker, 5 should-fix, 1 simpler, all accepted) and Jean's decisions (D1 a saved
  `faceToFace` flag set only by a New Game / Players choice of "A friend"; D2 Undo steps back; D3 first player left).
- Revision 3: Codex plan round 2 (1 blocker, 3 should-fix, all accepted): engine suppression iOS-only, compressible
  capture strip with a whole-column test, a mounted-screen analysis test, the rollout corrected for old friend games.
- Revision 4: Codex implementation review: D2 corrected to the engine's behaviour (Back keeps no variation: a different
  move after Undo replaces the undone one, as Back then a move does today); the bar is at least the fold's gap.
- Revision 5: Jean's request: a "Two Boards" toggle in the menu switches a friend game between the two boards and the
  single board (Step 6); an opened or pasted two-human game can now opt in.
- Revision 6: Codex plan review of Step 6: a mounted-screen test of the toggle, an imported mid-game PGN kept through
  both switches, and `setFaceToFace` returning early when the value does not change.

Jean's request (decided): when both players are human (`NewGame.Opponent.friend`), the friend across the table sees
the board upside down. On iPhone and iPad the game screen becomes **two boards of the same game**, one facing each
player:

- **Portrait:** two stacked halves. The bottom half is the first player's board from their side (today's
  `gameState.rotated`); the top half is the other player's board from the opposite side, the whole half (board,
  coordinates, its player rows, its status) turned 180°. Each half has the opponent row above its board, its own row
  below, and its own "to move" / result line.
- **Landscape** (iPad, iPhone sideways): the halves side by side, each turned 90° toward its player at a short end
  (left half toward the left edge, right half toward the right edge).
- On for every game started (or edited in Players) with "A friend" on iOS/iPadOS; an opened or pasted PGN starts on
  the single board with navigation (D1). The menu's "Two Boards" toggle switches either way in any two-human game
  (revision 5, Step 6). The Mac keeps today's single board.
- Between the halves, a thin bar with only **Undo** and **the menu** (what the toolbar and the More menu offer). No move
  strip, no evaluation bar, no navigation buttons.
- Only the board of the player on move takes taps. Selection, last move and arrows show on both. The promotion picker
  opens on the promoting player's board.

Mockup (option E): https://claude.ai/artifact/T8RBNZKaM9FZ7M9KiEHSFt

The honest size: one small pure type with its tests, one optional saved field, a `rotated` parameter threaded through five board views, a third
layout branch in `ContentView` (about 120 lines), the bar's menu passed in from the iOS shell, an orientation mask in a
small app delegate, a `.phoneLandscape` gallery size, about ten gallery cards and one UI test.

## 1. Problem, with evidence

- **The board has one orientation, read from the game everywhere.** Every board view reads
  `session.gameState.rotated` itself and maps squares with `Int.actual(rotated:)` (`Shared/Model/PlayAgainst.swift:13`):
  `BoardView.swift:38-39`, `PiecesView.swift:50-54` and `:77-81` (the promotion column),
  `VariationSelectionView.swift:24-31`, `LabelsView.swift:18-24` (its own `7 - index`). No parameter or environment value
  lets a second board draw from the other side.
- **The screen is laid out for one player.** `ContentView` (`Shared/Views/ContentView.swift:69-71`, `:110-116`) puts the
  player rows around one board, chosen by `topIsWhite = rotated`; the tall layout (`:185-206`) adds the status line,
  the engine card and the move strip; the wide layout (`:154-172`) a sidebar.
- **The iOS chrome is around that one board.** `iOS/GameRootView.swift:134-163`: Games and More in the navigation bar,
  the title (the players), and the bottom bar with `NavigationButtons` and the Engine toggle. There is no Undo on iOS
  today (the only undo is the Mac document's Edit ▸ Undo, `macOS/DocumentWindow.swift:98`); "back one move" is
  `GameSession.move(to: .backward)` (`GameSession.swift:322`), which `NavigationButtons` calls.
- **Taps are not gated by side.** `PiecesView.processTap` (`PiecesView.swift:16-26`) plays or selects for whoever taps;
  only the engine's legal moves limit it (`GameSession.select`, `:317`). Two live boards would let the player not on
  move select pieces and pick up the promotion picker.
- **The iPhone is portrait-only.** `iOS/Info.plist:65-68`. APP-8 lifted it and reverted it the same day
  (`planning/APP-8-iphone-duo.md`, revision 6) because the single board measured 151 pt in landscape. Two boards turned
  90° use the long side: each half is about 437 x 360 pt on an iPhone 17 Pro, so the turned board gets about 320 pt,
  more than in portrait.
- **Friend mode is known but has no name in the model.** `NewGame.isFriend` (`NewGame.swift:135`) is the sheet's;
  `GameState` (`GameState.swift:96-100`) only has `white.computer` and `black.computer`. A PGN opens with both players
  human (`GameState.init(data:contentType:)`), so "both human" cannot tell a friend game from an imported one: Jean
  decided (D1) that only a game set up as "A friend" gets two boards, which needs a saved flag (§2.0).
- **Accessibility identifiers are single.** `square-e4` etc. (`PiecesView.swift:40-41`, `:63`) and `board`
  (`ContentView.swift:90`) are used by `BChessUITests/BChessUITests.swift:25-29`; a second board would duplicate them.
  `testNewGameRemembersTheChoice` creates a friend game and then opens More ▸ New Game again, so the More button must
  stay reachable (and keep its label "More") in the new layout.

What already exists and is reused: `FoldLayout.split` and `ContentView.placement` (wide or tall, the fold), the
`PlayerRow` "White · to move" detail for friend games (`GameText.sideDetail`, `GameText.swift:79-83`), `StatusLine`
(result and last move), `neverMirrored()` (`BoardView.swift:15`), `GameSession.move(to: .backward)` and
`canMove(to:)`, the More menu's items (`GameRootView.swift:239-249`), and from APP-8 revision 5 the `.phoneLandscape`
gallery size design (screen transposed, compact / compact forced), which was removed with the revert.

## 2. Design

### 2.0 The saved flag: `GameState.faceToFace` (D1)

- `GameState` gains `var faceToFace: Bool` (an `init` parameter defaulting to `false`), coding key `faceToFace`, read with
  `decodeIfPresent(…) ?? false` and always encoded. Every `.json`/`.bchess` file an earlier BChess wrote opens with
  `false` (I1); an older BChess reading a newer file ignores the unknown key (synthesized-style `Decodable` with explicit
  keys skips extras). `GameState(data:contentType: .pgn)` leaves it `false`; PGN has no place for it and none is added:
  a game exported to PGN and opened again is single-board, by design.
- **Writers**, all from a players choice: `GameShell.createGame(white:black:rotated:…)` (`GameShell.swift:90-97`, the
  New Game sheet on iOS) and `GameSession.setPlayers(white:black:rotated:)` (`GameSession.swift:368-377`, the Players
  sheet on iOS, New Game and Players on the Mac) set `faceToFace = !white.computer && !black.computer`. So Players
  switching computer → "A friend" turns two boards on, "A friend" → a computer turns them off (the Players sheet shows
  "A friend" for any two-human game, `NewGame.swift:103-105`, so its Done on an imported game also turns them on — an
  explicit choice of "A friend"). `GameSession.paste` (`:381-394`) sets it `false`: a pasted game is studied with
  navigation. `load(_:)` takes the flag with the rest of the state (Mac Undo/Revert).
- **Reader:** `FaceToFace.isOn(state)`; **screen:** `ContentView`'s face-to-face branch and `GameView`'s bars and
  orientation mask.

### 2.1 One pure type: `FaceToFace` (`Shared/Model/FaceToFace.swift`)

```swift
nonisolated enum FaceToFace {
    /// A game set up as "A friend" (the saved flag, both players still human): the iOS game screen shows two boards.
    static func isOn(_ state: GameState) -> Bool            // state.faceToFace && !white.computer && !black.computer
    /// The engine readout and its analysis run only on the single board. The Mac always has the single board and
    /// its engine controls, so there it is `setting` whatever the flag.
    static func showsEngine(setting: Bool, state: GameState) -> Bool   // iOS: setting && !isOn(state); macOS: setting
    /// The colour at the bottom of a half: the near half is the first player's (today's board).
    static func bottomIsWhite(near: Bool, rotated: Bool) -> Bool   // near ? !rotated : rotated
    /// The board takes taps only for the side to move.
    static func acceptsMoves(bottomIsWhite: Bool, isWhiteToMove: Bool) -> Bool
    /// The turn of a half, in degrees clockwise: tall 0 (near) / 180 (far); wide 90 (near, left half, its bottom
    /// toward the left edge) / -90 (far, right half).
    static func turn(near: Bool, wide: Bool) -> Double
    #if os(iOS)
    /// iPad: every orientation. iPhone: portrait, plus landscape while a friend game is open.
    static func orientations(isPad: Bool, faceToFace: Bool) -> UIInterfaceOrientationMask
    #endif
}

#if os(iOS)
/// The mask the app delegate answers; the game screen updates it from the open game.
@MainActor enum OrientationLock {
    static private(set) var mask: UIInterfaceOrientationMask = .portrait
    /// Sets the mask from the game and, when it changed, tells UIKit (see §2.6).
    static func update(for state: GameState, isPad: Bool)
}
#endif
```

Each function has at least two callers (the two halves, or the layout and the app delegate); no state.

### 2.2 The orientation as a parameter

`BoardFrame`, `LabelsView`, `BoardView`, `PiecesView` and `VariationSelectionView` take `rotated: Bool` (no default)
instead of reading `session.gameState.rotated`. A half draws with `rotated = !bottomIsWhite`; the single layout passes
`session.gameState.rotated`, so it is unchanged. `Promotion.screenRow/screenFile` already take `rotated`. The game state
is never mutated to draw the far board, and Flip Board (`GameSession.rotate()`) still swaps who sits where.

Why it works with one turn: the far half is laid out exactly as the far player would see a single board with their
colour at the bottom (opponent row, board with `rotated = !gameState.rotated`, own row, status) and then turned 180°.
Board, coordinates and text all come out upright for that player, their pieces nearest to them. `rotationEffect` also
turns hit testing and the accessibility frames, so taps land on the right squares.

### 2.3 Taps, selection, promotion

- `PiecesView` gains `acceptsMoves: Bool`. The half that does not accept moves is `.allowsHitTesting(false)` (pieces,
  arrows) and `.accessibilityHidden(true)` as a whole (board and rows), so `square-e4`, `board` and `variation-N` stay
  unique and always belong to the board that can play: they move to the other board after each move.
- `PiecesView` draws the promotion overlay only when `acceptsMoves`; the promotion is begun by the player on move
  (`beginPromotion`, `GameSession.swift:457`) before the move is played, so it shows on that player's board only.
- Selection, last move and arrows are session state (`selection`, `lastMove`, `variations`) and both boards draw them.
- `startIfNeeded()` in `PiecesView.onAppear` is idempotent (`hasStarted`, `GameSession.swift:552`); two boards call it
  harmlessly, and no computer plays anyway.

### 2.4 The layout (`ContentView`, iOS only)

`ContentView` gets a third branch, `faceToFaceLayout`, taken when `#if os(iOS)` and `FaceToFace.isOn(gameState)`;
the wide/tall decision is the existing `placement.isWide` (usable area wider than tall), so iPad split-view and Stage
Manager windows narrower than tall get the stacked halves.

- **A half** (`half(near:)`): a `BoardColumn(leading: 0)` (`Shared/Views/BoardColumn.swift`, reused: it measures the
  rows and gives the board the largest square that fits what is left, the rows as wide as the board) holding
  `PlayerRow` (opponent), the board (marked `BoardColumn.IsBoard`; `BoardFrame` + the three board views with the half's
  `rotated`, no evaluation bar, the mode ring as today), `PlayerRow` (own) and `StatusLine`, centred in its slot.
  `boardRows`/`board` in `ContentView` become `board(rotated:)` so the single layout and the halves share one board
  builder (the `board` accessibility element stays on it).
- **Rows never wider than the half.** `BoardColumn.fit` keeps the column at least as wide as its widest row's minimum
  width, and `PlayerRow`'s capture strip (22 pt per piece, `PlayerRow.swift:55-67`) has no minimum below its full
  length: fifteen captures and a long name exceed a 343 pt half. The strip becomes compressible: a `ViewThatFits`
  between the 22 pt pieces and 14 pt pieces, then the name truncates (`lineLimit(1)` already) and the strip clips at the
  row's trailing edge, so the row's minimum width stays under the half's width. The single layout gets the same row; its
  existing cards are unchanged because their strips fit at 22 pt (checked byte for byte at step 3).
- **Tall:** `VStack { far half turned 180°; bar; near half }`, halves equal height.
- **Wide:** `HStack { near half turned 90°; bar (vertical); far half turned -90° }`. A quarter turn swaps the slot's
  axes: a private `turned(_:)` helper lays the half out in the slot's transposed size, turns it, and frames it back to
  the slot (`GeometryReader`), used by both halves. The HStack is pinned left to right so the near half is on the left
  in every language; each half gets the screen's layout direction back, so its rows mirror as chrome does.
- **Fold (iPhone Duo inner display):** the halves and the bar use `placement.split` along the stacking axis: with a fold
  inside (`split.primary`), the first half is `primary` long, the bar fills the `gap`, the second half the rest, so no
  board lies on the hinge. Without a fold, the halves are equal around the bar.
- **The engine:** no evaluation bar, no engine card, and the body observes the effective value,
  `.onChange(of: FaceToFace.showsEngine(setting: showEngine, state: session.gameState), initial: true)` (today it
  observes `showEngine` only, `ContentView.swift:246-248`), so Players switching a computer game to "A friend" with the
  engine on stops the analysis in the same screen. On the Mac `showsEngine` returns the setting, so a friend game there
  (the flag is written by the Mac's New Game and Players too) keeps its analysis. The setting itself is untouched.
- **The bar** (Shared, drawn by `ContentView`): Undo (`arrow.uturn.backward`, label "Undo", calls
  `withAnimation { session.move(to: .backward) }`, disabled when `!session.canMove(to: .backward)`) and a `Menu` labelled
  `Label("More", systemImage: "ellipsis.circle")` whose items the shell passes in. `ContentView` becomes generic over the
  menu items, `ContentView<MenuItems: View>`, with the existing `init(session:foldRegions:)` (MenuItems == EmptyView, the
  Mac and the existing gallery cards) and `init(session:foldRegions:menuItems:)`. Undo steps back one move, as Back does
  today: the engine then replaces the undone move when a different one is played, with no variation (D2, decided).

### 2.5 The iOS shell (`iOS/GameRootView.swift`)

- `moreMenu`'s items move into a `@ViewBuilder moreMenuItems`; the navigation bar keeps `Menu { moreMenuItems }`, and
  `ContentView(..., menuItems: { Button("Games") { showGames = true }; moreMenuItems })` gets the same items plus
  Games. "Flip Board" stays: it swaps the seats.
- In a friend game the navigation and bottom bars are hidden: `.toolbar(faceToFace ? .hidden : .automatic, for:
  .navigationBar, .bottomBar)`. The title (the players' names) is already on the rows.

### 2.6 iPhone landscape, only face to face

- `iOS/Info.plist`: the iPhone list gains `UIInterfaceOrientationLandscapeLeft` and `…Right` (the build-time maximum).
- A small `AppDelegate` (`@UIApplicationDelegateAdaptor` in `BChessUIApp`, iOS only) answers
  `application(_:supportedInterfaceOrientationsFor:)` with `OrientationLock.mask`. `GameView` calls
  `OrientationLock.update(for: session.gameState, isPad:)` in `.onChange(of: FaceToFace.isOn(gameState), initial: true)`.
  When the mask changes, `update` tells UIKit through the API each object actually has: for every connected
  `UIWindowScene`, `rootViewController?.setNeedsUpdateOfSupportedInterfaceOrientations()` on its key window (a
  `UIViewController` method; SwiftUI's hosting controller asks the delegate again), then
  `scene.requestGeometryUpdate(.iOS(interfaceOrientations: mask))`, which rotates a sideways iPhone back to portrait
  when the mask drops landscape. Leaving the friend game (new game against the computer, Players, paste, opening another
  game) thus returns to portrait; the single board never shows in landscape on an iPhone, so APP-8's 151 pt board
  cannot come back.

## 3. Alternatives rejected

- **Mutate `gameState.rotated` for the second board, or a second `GameSession`.** Persisted state (I1: saved files)
  would flip on every draw, and a second session would duplicate the engine and the I2 tokens. A parameter is the
  smallest correct seam.
- **An environment value for the orientation with a fallback to the game.** Two ways to know the orientation; five
  views with an explicit parameter are as short and cannot forget it.
- **Rotate the near half's view 180° instead of drawing the far half from the other side.** A 180° turn of the near
  layout puts the far player's opponent row nearest to them and the coordinates on the wrong sides; the far half must be
  laid out as the far player's single board, then turned.
- **Prefixing the far board's identifiers (`top-square-e4`).** Tests would need to know which board is on move; hiding
  the half that cannot play keeps one live set, and VoiceOver reads only the board that can move.
- **A setting, or a "face to face" toggle.** Jean decided: always on, no setting.
- **Two boards for every two-human game, with no saved flag.** Imported and pasted games (studies) would lose
  navigation; Jean chose the flag (D1).
- **The bar built by the shell around `ContentView`.** The bar sits between the halves inside the layout; passing only
  the menu items keeps the layout in one place and lets the gallery render the real bar.
- **iPhone landscape for every game.** Reverted in APP-8 for the single board (151 pt); unlocked only where it helps.

## 4. Test plan

**Failing Swift Testing tests first** (`BChessTests/FaceToFaceTests.swift`, `@Suite struct FaceToFaceTests`):

- `isOnOnlyForAFriendGame` (arguments: flag on + human/human true; flag off + human/human false; flag on with a
  computer side, either colour, false) — the mode switch, and a computer game keeps today's screen.
- `showsEngineOnlyOnTheSingleBoard` — `showsEngine(setting:state:)` for the four combinations (`#if os(iOS)`), and
  `macKeepsTheEngineInAFriendGame` (`#if os(macOS)`, run by the Mac test gate): a friend game with the setting on gives
  true.
- In `GameStateCodingTests`: `oldFileWithoutFaceToFaceOpensSingleBoard` (a real older JSON shape, the four keys only,
  decodes with `faceToFace == false`), `faceToFaceRoundTrips` (true and false survive encode/decode), and
  `pgnOpensSingleBoard` (`GameState(data:contentType: .pgn)` of a two-human PGN has the flag off).
- In `GameShellTests`: `createGameAgainstAFriendSetsTheFlag` (human/human → true, saved and reopened from the library
  still true; human/computer → false).
- In `GameSessionTests`: `playersSwitchTurnsTwoBoardsOnAndOff` (`setPlayers` computer → friend sets it, friend →
  computer clears it), `pasteKeepsTheSingleBoard` (paste in a friend game clears it), and
  `friendSwitchStopsTheAnalysis` (engine on, `showsEngine = true` and analysing a human-vs-computer game; `setPlayers`
  to two humans, then `showsEngine = FaceToFace.showsEngine(…)`: `isAnalyzing` becomes false and no analysis callback
  changes `info` afterwards) — the session half of the rule.
- In `GalleryScenarioTests` (iOS-hosted, the harness the oracle tests use): `mountedScreenStopsAnalysisWhenPlayersBecomeFriends`
  mounts the production `ContentView` with `engineOnDefaults` in a window through the window setup of
  `SnapshotGalleryTests.render` (extracted as a `mount` helper that keeps the window until the test ends — its second
  caller), waits for `session.isAnalyzing`, calls `setPlayers(white: .human, black: .human)`, and waits (bounded) for
  `isAnalyzing == false` with no later `info` change — the production observation, not a hand assignment.
- `bottomColourOfEachHalf` (near/far × rotated) — the near half is today's board, the far half its opposite.
- `onlyTheSideToMoveAcceptsMoves` (all four combinations).
- `turnsFaceEachPlayer` — tall 0/180, wide 90/-90.
- `iPhoneUnlocksLandscapeOnlyFaceToFace` and `iPadAllowsEveryOrientation` (`#if os(iOS)`; the Mac test run skips them by
  compilation, the iOS run executes them).
- `appDelegateAnswersTheMaskOfTheOpenGame` (`#if os(iOS)`, main actor, serialized: the mask is process-wide):
  `OrientationLock.update(for:isPad: false)` with a friend game's state, then
  `AppDelegate().application(.shared, supportedInterfaceOrientationsFor: nil)` includes landscape; with a computer
  game's state, portrait only — the production read path from the game state to the delegate's answer.
- In `GameSessionTests`: `undoInAFriendGameGivesTheMoveBack` — two humans, play e2–e4, `move(to: .backward)`: White to
  move, `canMove(to: .backward) == false`, and `acceptsMoves(bottomIsWhite: true, isWhiteToMove:)` is true again; then a
  different move (d2–d4) is played and replaces the undone one: one half-move, no variation (the D2 behaviour,
  written down).

The views are exempt from unit tests; they are covered by the gallery and one UI test.

**Path from data to screen:** the field is written by `GameShell.createGame` and `GameSession.setPlayers` (cleared by
`paste`), saved through `GameState`'s encoder; `FaceToFace.isOn(session.gameState)` is read by `ContentView` (layout)
and `GameView` (bars, `OrientationLock`). The shell scenario below renders it through `GameRootView` with a library holding a friend game, the
production reader, not a test-only path.

**Gallery scenarios** (`BChessGalleryTests/GalleryScenarios.swift`, group "Face to face"; the friend session is
`GameSession(state: GameState(pgn:, rotated:, white: .human, black: .human, faceToFace: true))`, the menu items a real `Button("New
Game") {}` since a closed menu draws only its label):

- `Face to face · Start` (`.phone`): iPhone portrait; the `--device ipad` pass renders it as iPad portrait, the
  `--device duo` pass as the folded Duo.
- `Face to face · Black at the bottom` (`.phone`, `rotated: true`): the orientation plumbing both ways.
- `Face to face · Mid-game` (`.phone`, `Fixture.middlegame`, a piece selected): last move and selection on both boards.
- `Face to face · Promotion on the top board` (`.phone`): a new `Fixture.blackPromotes` (a `[FEN]` PGN with a black pawn
  on the 2nd rank, Black to move, White at the bottom); the scenario selects the pawn and begins the promotion, so the
  picker shows on the turned top board only.
- `Face to face · Checkmate` (`.phone`, `Fixture.checkmate`): the result on both halves, the Undo bar.
- `Face to face · Small iPhone · Largest text` (`.smallPhone`, `.dynamicTypeSize(.accessibility3)` on the scenario — a
  text size, neither an appearance nor a language, as `GalleryScenarioTests.wideImage` already does): the rows at their
  tallest and the smallest boards, on a late friend game with many captures (`Fixture.worstRow`, fifteen captured
  pieces, as a friend game). An oracle test in `GalleryScenarioTests`, `faceToFaceColumnsStayInTheirHalves`
  (`.smallPhone` and `.phone`, default and `.accessibility3`, `Fixture.worstRow`), measures each half's whole column —
  rows, board and status, through the frame-colour `boxes` helper for the board and the non-background extent for the
  rows — and checks it lies inside its half, nothing under the bar and nothing past the window's edges.
- `Face to face · iPad landscape` (`.ipadLandscape`): side by side, each turned 90°.
- `Face to face · iPhone landscape` (new `GallerySize.phoneLandscape`: the screen transposed, 874 x 402 on the
  iPhone, 678 x 466 on the Duo pass; compact / compact forced, the scene stays portrait — APP-8 revision 5's design).
- `Duo inner · Landscape · Face to face` (`.duoInnerLandscape`, `duoLandscapeHinge`) and `Duo inner · Portrait ·
  Face to face` (`.duoInnerPortrait`, `duoPortraitFlat`), group `groupDuo`: the halves on each side of the fold.
- `Face to face · Shell` (`usesSystemBars: true`): `GameRootView` on a scratch library whose one game is a friend game
  — the navigation and bottom bars are gone, the bar's menu is the shell's.

`GalleryScenarioTests.manifestRecordsPointsAndScale` covers the new size. The existing Board, Pieces, Promotion and
Game screen cards stay byte for byte the same after step 2 (`magick compare -metric AE`, 0).

**Right to left:** `snapshot-gallery.sh --only "<the Face to face cards>" --lang he,ar`, with `--device ipad`, and
`--device duo` for the two `Duo inner · … · Face to face` cards (the inner-display captures AGENTS.md asks for): each
board's region compared with the English capture (`magick compare -metric RMSE`, 0), the near half on the left in
landscape.

**UI test** (`BChessUITests`, `testFaceToFaceEachBoardPlaysItsSide`): More ▸ New Game ▸ `new-game-opponent-friend` ▸
start; tap `square-e2`, `square-e4` (the board on move, whichever colour sits at the bottom); then `square-e7`,
`square-e5` — the only live identifiers are now on the other board, so the taps land on it (turned 180° when White was
at the bottom); the `board` value reads White to move, move 2; tap Undo: Black to move. Then a **coordinate tap on
the inactive half**: the centre of a square holding one of the side to move's pieces, computed from the hidden board's
frame (`app.coordinate(withNormalizedOffset:)` on the window, the halves' geometry known from the layout), must leave
the `board` value and the selection unchanged.

`testFaceToFacePromotionOnTheTurnedBoard` (run in portrait, then again after `XCUIDevice.shared.orientation =
.landscapeLeft`): a friend game played to a Black promotion through identifiers (1. a4 h5 2. a5 h4 3. a6 h3 4. axb7
hxg2 5. h4 gxh1); the queen's `promote-…` button exists and is hittable on the board on move, and its tap gives a black
queen on h1 (the `square-h1` value).

`testLandscapeOnlyFaceToFace` (iPhone): in a friend game, `XCUIDevice.shared.orientation = .landscapeLeft` → the app
window is wider than tall; still sideways, More ▸ New Game ▸ Club ▸ start → the window is taller than wide (back to
portrait); `.portrait` restores the device at the end. This covers GameView → `OrientationLock` → delegate → rotation.

The existing `testNewGameRemembersTheChoice` must still pass (More is in the bar in a friend game).

**Gates.** Step gates as `gates.md`. Landing gate: the quick tier on Mac and iOS (FaceToFaceTests run on both), the
UI suite `BChessUITests` on the leased iPhone and on an iPad lease (`--spec ipad`; identifiers, the bar and the
promotion in both layouts; `testLandscapeOnlyFaceToFace` is iPhone-only and skips on the iPad); the gallery: iPhone pass,
`--device ipad`, `--device duo`, and the `--lang he,ar` checks above (iPhone, iPad, Duo), shown to Jean;
`scripts/snapshot-mac.sh` once to show the Mac cards unchanged (`ContentView` changed shape). `catalog-sync` for the new
key "Undo" (all six languages).

## 5. Invariants

- **I1 — Files keep opening:** at risk, held. A field is added: `faceToFace`, read with `decodeIfPresent` and default
  `false`, so every file an earlier BChess wrote opens (single board, as before); `oldFileWithoutFaceToFaceOpensSingleBoard`
  holds it with a real older JSON shape. PGN is untouched and stays standard (no new tag). `rotated` keeps its meaning.
- **I2 — A search result only lands on its position:** holds. No search starts in a friend game (no computer), Undo goes
  through `move(to:)` which bumps `positionID`, and the analysis is turned off while two boards show
  (`showsEngine && !faceToFace`). No main-thread wait is added.
- **I3 — The engine stays portable:** not applicable (no engine change).
- **I4 — The UCI tool keeps working:** not applicable.
- **I5 — Private and offline:** holds. No network; no new required-reason API (`UserDefaults` is already declared and no
  new key is added; the orientation API is not a required-reason API).

## 6. Risks and rollout

- **Hit testing and accessibility under `rotationEffect`.** Expected to follow the turn; proven by the UI test (taps on
  the turned board through identifiers) and by hand on a device.
- **iPhone landscape.** The unlock follows the mode; a regression would bring back APP-8's landscape single board.
  `iPhoneUnlocksLandscapeOnlyFaceToFace`, `appDelegateAnswersTheMaskOfTheOpenGame` and `testLandscapeOnlyFaceToFace`
  hold it; on a device as well: rotate in a friend game, start a game against the computer while sideways (back to
  portrait), and the Control Center orientation lock.
- **Small halves.** At the largest Dynamic Type sizes the rows grow and the boards shrink; the smallest iPhone
  (`.smallPhone`, 375 x 667) gives each half about 300 pt of height. Covered by the Largest text card and
  `faceToFaceColumnsStayInTheirHalves` with fifteen captures; the compressible capture strip bounds the rows.
- **The Duo.** The bar sits on the fold's gap; on a real inner display, check that Undo and More are tappable there and
  the boards stay off the hinge (flat and tabletop).
- **Edges.** The far player's back rank sits near the status bar / Dynamic Island, which the safe area keeps clear;
  check on a device that swipes from the top edge (Notification Center) do not get in the way of play.
- **File-format compatibility:** one optional field, held as in I1; an older BChess opening a newer file ignores it. **Real device owed:** two people playing a whole game on an iPhone flat on
  a table and on an iPad in both orientations, promotion by the far player, Undo, iPad multitasking resize switching
  between stacked and side by side, the Duo inner display.
- Rollout: no setting and no migration. Friend games saved before this build decode with `faceToFace == false` and
  keep the single board; Players ▸ "A friend" ▸ Done (or a new game against a friend) turns two boards on. Every new
  friend game has them from the start.

## Step 6 — switch between two boards and the single board

Jean's request (decided): in a friend game on iPhone/iPad the player switches between the two boards and the regular
single board (one board, move list, navigation, the engine per Settings) with a "Two Boards" on/off item in the menu,
shown only when both players are human, never on the Mac. It writes the saved `GameState.faceToFace`, so the choice
stays with the game. The honest size: one rule, one session method, one menu item, one string, a few tests.

- **The rule:** `FaceToFace.canSwitch(_ state: GameState) -> Bool` = `!white.computer && !black.computer`, whatever the
  flag. Callers: the menu (shows the item) and `setFaceToFace` (ignores the call otherwise). So every two-human game
  offers the item, including an opened or pasted PGN and a friend game saved before this build, which can then opt in
  (recommended: the toggle is an explicit choice, as Players ▸ "A friend" already was; D1's default is unchanged).
- **The writer:** `GameSession.setFaceToFace(_ on: Bool)`: `guard FaceToFace.canSwitch(gameState) else { return }`,
  `gameState.faceToFace = on`, `invalidate()`, the same path as `setPlayers` (a players-and-mode change: `positionID`
  bumps, pending searches dropped). Not a fourth writer rule: `createGame`, `setPlayers` and `paste` keep theirs.
- **Edited and undo:** as changing players does on iOS: the `gameState` change autosaves through `GameView`'s
  `.onChange(of: shell.session.gameState) { shell.save() }`; iOS has no undo for Players, and none for this either
  (the game Undo in the bar stays a move undo). The Mac never calls it.
- **The item:** in `moreMenuItems` (`iOS/GameRootView.swift`), after "Flip Board":
  `if FaceToFace.canSwitch(state) { Toggle("Two Boards", systemImage: "rectangle.split.1x2", isOn: Binding(get:
  { FaceToFace.isOn(state) }, set: { shell.session.setFaceToFace($0) })) }`. A `Toggle` in a `Menu` draws its
  checkmark. `moreMenuItems` feeds both the navigation bar's More menu (single board) and the bar between the boards
  (`ContentView(menuItems:)`), so the way back is always there. iOS only by construction: the file is the iOS shell.
- **Engine and I2:** switching on hides the readout through the existing effective value (`FaceToFace.showsEngine` →
  `ContentView`'s `.onChange(of: showEngine)` → `session.showsEngine = false`), which stops the analysis, and
  `invalidate()` has already bumped `positionID`, so no callback from the earlier search lands (I2). Switching off
  restarts the analysis when Settings has the engine on, on the current position. No search plays a move in a
  two-human game; the main thread waits on nothing.
- **Orientation:** `GameView`'s `.onChange(of: FaceToFace.isOn(…), initial: true)` already calls
  `OrientationLock.update`: on → iPhone landscape allowed; off while sideways → back to portrait. Nothing new.
- **String:** "Two Boards" in `Shared/Localizable.xcstrings` (`catalog-sync`): fr "Deux échiquiers", de "Zwei
  Bretter", it "Due scacchiere", he "שני לוחות", ar "رقعتان" (the "Flip Board" words: échiquier, Brett, scacchiera,
  לוח, رقعة).

**Tests** (failing first):

- `FaceToFaceTests.canSwitchOnlyWhenBothPlayersAreHuman` (parameterized: human/human with the flag on and off → true;
  either side a computer → false).
- `GameSessionTests`: `setFaceToFaceSwitchesTheBoards` (a two-human PGN game off → on → off, `FaceToFace.isOn`
  follows); `setFaceToFaceIgnoresAComputerGame` (the flag stays false); `"setFaceToFace"` added to the `expectBump`
  list (the I2 bump).
- `GameShellTests.twoBoardsChoiceSurvivesSaveAndReopen`: open a two-human game, switch on, `save()`, the file and a
  reopened shell have `faceToFace`; switch off, the same with false.
- UI test `testFriendGameSwitchesBetweenTwoBoardsAndOne`: start a friend game; More ▸ "Two Boards" (off): one
  `square-e2`, no `board-inactive`, the "Games" button exists (the move list is a sheet on a compact width, so it is no signal); More ▸ "Two Boards" (on): `board-inactive` again, "Games" gone. On
  an iPhone, sideways while on, then off: `waitForWindow(app, wide: false)`. The open menu, with the item checked, is
  kept as a screenshot attachment (`XCTAttachment`, `.keepAlways`): the gallery draws the host view's hierarchy, which
  has no presented menu, so no card can show an open menu.
- `GameSessionTests.setFaceToFaceWithTheSameValueDoesNothing`: `setFaceToFace` returns early when the value does not
  change (no `invalidate()`: `positionID` stays, so a redundant call cancels no pending promotion and restarts no analysis).
- `GameSessionTests.switchingKeepsAnImportedGameInPlace`: an imported two-human PGN (two games) on its second game, at a
  middle position: switching on and off keeps the FEN, the current game, the current move and the PGN.
- `GalleryScenarioTests.mountedScreenFollowsTheTwoBoardsToggle` (the mounted-screen harness, Engine setting on): two
  boards on through `setFaceToFace` stop the analysis through the production `ContentView.showEngine` observation, a
  callback with the old token is rejected, and switching off restarts the analysis.
- Gallery: "Face to face · Two boards off" (`friendShell` with `faceToFace: false`: the production single board, its
  bars, move list and navigation, for two human players).

## 7. Decision left open for Jean

None. Decided by Jean (2026-11-21): **D1** two boards only for a game set up as "A friend" in New Game or Players,
saved as `GameState.faceToFace` (§2.0); opened and pasted PGNs start on the single board (Step 6's toggle can switch them). **D2** Undo steps back one move
(today's Back; a different move afterwards replaces the undone one, with no variation). **D3** the first player's half on the left
in landscape; Flip Board swaps the seats.

## Steps

1. **FaceToFace rules and the saved flag** — `GameState.faceToFace` and its writers (`createGame`, `setPlayers`,
   `paste`), `Shared/Model/FaceToFace.swift` (`OrientationLock` included, unused until step 4), the tests of §4 for the
   flag, the rules and `undoInAFriendGameGivesTheMoveBack` (failing first); `xcodegen generate` if the project needs it.
2. **Orientation as a parameter** — `rotated:` on `BoardFrame`, `LabelsView`, `BoardView`, `PiecesView`,
   `VariationSelectionView`; `ContentView` and the gallery pass `session.gameState.rotated`; `board(rotated:)` in
   `ContentView`; the existing cards byte for byte the same.
3. **Two stacked boards** — `faceToFaceLayout` (tall), the halves, the bar with Undo and the menu, `ContentView<MenuItems>`,
   `acceptsMoves` (hit testing, accessibility, promotion), engine off in this mode; `GameView` passes the menu items and
   hides its bars; the effective engine value observed (`friendSwitchStopsTheAnalysis`); "Undo" in the String Catalog;
   the portrait, Duo portrait, promotion, checkmate, mid-game, Largest text and shell gallery cards and
   `faceToFaceColumnsStayInTheirHalves`, the compressible capture strip, `mountedScreenStopsAnalysisWhenPlayersBecomeFriends`.
4. **Side by side and iPhone landscape** — the wide branch with the quarter turns and the left-to-right pin, the fold
   split; `Info.plist`, the app delegate, `OrientationLock.update` wired in `GameView`
   (`appDelegateAnswersTheMaskOfTheOpenGame`); `GallerySize.phoneLandscape`; the iPad landscape, iPhone landscape and
   Duo landscape cards.
5. **UI tests** — `testFaceToFaceEachBoardPlaysItsSide`, `testFaceToFacePromotionOnTheTurnedBoard` and
   `testLandscapeOnlyFaceToFace` in `BChessUITests`.
6. **Switch layouts** — `FaceToFace.canSwitch`, `GameSession.setFaceToFace`, the "Two Boards" toggle in `moreMenuItems`
   (both menus), the string and its translations, the Step 6 tests (unit failing first, the UI test, the gallery card).
