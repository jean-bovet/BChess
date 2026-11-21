# APP-13 — A clear indication when a game is won or drawn

Revision 2 (2026-11-21; r2: Jean's decisions D1–D5 recorded, all as recommended). Issue #62 (TestFlight feedback, iPhone). Related, not in scope: #61 (layout and duplicate
information on the game screen).

## Problem, with evidence

When a game ends, the only sign is the grey status line: "Checkmate. White wins. Last: 67. Qb7#".

- `StatusLine` (`Shared/Views/StatusLine.swift:20-27`) is one `.subheadline`, `.secondary` text. Its game-over
  sentences come from `GameText.status` (`Shared/Model/GameText.swift:103-113`): "Checkmate. White wins." /
  "Checkmate. Black wins.", "Stalemate.", "Draw by repetition.", "Game over." (a declared result, winner not said).
- **It disappears while browsing.** `GameSession.gameEnd` (`Shared/Model/GameSession.swift:188-192`) is
  `engine.gameEnd`, computed by `ChessEngine::gameEnd()` (`Shared/Engine/Engine/ChessEngine.hpp:163-176`) on the board
  **at the cursor** (`ChessGame::moveTo` replays to the cursor, `ChessGame.cpp:157-179`, `replayMoves` `:201-215`). One
  step back from the mate, the position has legal moves, `gameEnd == .none`, and the status line says "White to move.
  Last: …" again. Nothing anywhere knows "this line ended in mate".
- **Two of the issue's draws are not game ends.** The engine has `ChessEvaluater::isFiftyMoveDraw`
  (`ChessEvaluater.cpp:247`) and `ChessEvaluater::isDeadPosition` (`ChessEvaluater.cpp:259`, FIDE's dead positions:
  insufficient material), but only the search uses them (`MinMaxSearch.hpp:213`, `ChessEvaluater.cpp:300`).
  `gameEnd()` ignores both, so the app shows "White to move." and the computer keeps playing on in K v K or after
  fifty moves (`GameSession.requestEngineMoveIfNeeded` guards on `engine.canPlay()`, `GameSession.swift:518`).
- **A declared result never says who won.** `ChessGame::outcome` (`ChessGame.hpp:22-24`, set from the PGN
  termination marker in `FPGN::parseTerminationMarker`, `FPGN.cpp:374-399`) is not bridged; `.finished` reads
  "Game over.".
- The player rows drop the "to move" accent once the game is over (`PlayerRow.toMove`, `PlayerRow.swift:25-27`) and
  say nothing else. No alert, sheet or banner exists (`iOS/GameRootView.swift`, `macOS/DocumentWindow.swift`).
- Gallery: the only finished-game card is `statusLineCheckmate` (`BChessGalleryTests/GalleryScenarios.swift:229`),
  the status line alone. No game-screen, iPad, Duo or Mac card of a finished game; no stalemate or draw fixture
  (`GalleryFixtures.swift:82` has the fool's mate only).

## Design

The smallest change that makes the result prominent and keeps it while browsing: the engine says how the **current
line** ends (not the position on screen), the session turns that into a `GameResult`, and one new view, a result
banner, shows it in the status line's slot. The status line keeps its job (whose move, the last move) and loses its
game-over sentences when the banner is up, so the result is said once.

### 1. Engine: two more game ends, and the end of the line

`Shared/Engine/Engine/ChessEngine.hpp`:

- `GameEnd` gains `fiftyMoves` and `deadPosition`. `gameEnd()` checks, in order: no legal move (checkmate /
  stalemate, unchanged), repetition (unchanged), `ChessEvaluater::isFiftyMoveDraw(board)`,
  `ChessEvaluater::isDeadPosition(board)`, then the declared result (unchanged). Both helpers exist and are tested;
  `isFiftyMoveDraw` already lets a mate on the hundredth half-move stand. (Decision D3: whether these end the game.)
- The body of `gameEnd()` moves into `static GameEnd gameEnd(ChessGame &g)`; `gameEnd()` calls it on `game()`.
- New `LineResult lineResult()` returning `{ GameEnd end; ChessGame::Outcome outcome; }` for the **last position of
  the current line** (`moveIndexes.moves`, the path the cursor walks):
  - at the end of the line (`getNumberOfMoves() == getLineLength()`), `gameEnd(game())`;
  - otherwise a copy: `ChessGame copy = game(); copy.history = NEW_HISTORY; copy.moveTo(Direction::end);` then
    `gameEnd(copy)`. **The fresh history is load-bearing**: `history` is a `shared_ptr` and `replayMoves` clears it, so
    without it reading the result would wipe the live game's repetition history (the same reason `FEngine.mm`'s
    `infoFor:` copies with `NEW_HISTORY`).
  - `outcome`: checkmate gives the side not to move at the line's end; stalemate, repetition, fifty moves and dead
    position give `draw`; `finished` gives `game().outcome`; `none` gives `in_progress`.

No search code changes (`MinMaxSearch` keeps its own draw rules; the root is still never drawn by rule).

### 2. Bridge

`Shared/Bridge/FEngine.h/.mm`: `GameEndFiftyMoves`, `GameEndDeadPosition` in the existing `NS_CLOSED_ENUM GameEnd`
(and the `gameEnd` switch); a new `NS_CLOSED_ENUM GameOutcome { GameOutcomeInProgress, GameOutcomeWhiteWins,
GameOutcomeBlackWins, GameOutcomeDraw }`; two readonly properties `lineEnd` (`GameEnd`) and `lineOutcome`
(`GameOutcome`), both from one `engine.lineResult()` call each (cheap: a copy and a replay of one line, only off the
line's end).

### 3. Model

`Shared/Model/GameSession.swift`, beside `gameEnd`:

```swift
/// How the current line ends, whatever position is on screen; nil while it is still being played.
var result: GameResult? { _ = revision; … engine.lineEnd / engine.lineOutcome … }
/// Whether the position on screen is the line's last one.
var isAtLineEnd: Bool { !canMove(to: .forward) }   // the existing navigation check, `GameSession.swift:163`
```

`GameResult` (new, `Shared/Model/GameResult.swift`, `nonisolated struct … : Equatable, Sendable`):
`winner: Winner` (`.white`, `.black`, `.draw`) and `reason: GameEnd` (never `.none`). Second caller: `StatusLine`
and `ResultBanner` both read it (and #61's layout work will). No other new type.

Behaviour this gives, all from existing navigation:
- Browsing back from a mate keeps `result` (white or black wins by checkmate) while `gameEnd == .none`.
- Playing a different move from an earlier position starts a variation whose line ends at that move: `result` becomes
  nil and the game goes on (today's behaviour for play is unchanged).
- Picking a variation while browsing shows how *that* line ends (nil if it is unfinished).

### 4. Text (`Shared/Model/GameText.swift`)

- `GameText.resultTitle(_:) -> String`: "White wins" / "Black wins" / "Draw". Colour, not player name (D2).
- `GameText.resultReason(_:) -> LocalizedStringResource?`: "Checkmate", "Stalemate", "Threefold repetition",
  "Fifty-move rule", "Insufficient material"; nil for a declared result (`.finished`), which shows the title alone.
- `GameText.status`: when the banner is up (a result and the cursor at the line's end), `StatusLine` is not shown, so
  `status` loses the "Checkmate. … wins." and "Game over." sentences. A position in the middle of a line that cannot
  be played (an imported game that continued past a repetition, fifty moves or a dead position) keeps a status:
  the reason leaf (`resultReason`) plus the usual "Last:" suffix. "Stalemate." / "Draw by repetition." /
  "Checkmate. White wins." / "Checkmate. Black wins." / "Game over." become stale and are deleted
  (`catalog-sync --delete-stale`).
- New keys (all leaves, no concatenation, no numbers, no isolates): the three titles and five reasons, each with fr,
  de (Swiss spelling, no ß), it, he, ar. Run `catalog-sync`, translate, `catalog-sync --delete-stale`,
  `catalog-sync --check --skip-build`. Add the leaves to `BChessMacGalleryTests/LocalizationExpectations.swift` so
  `LocalizationTests` resolves them per language.

### 5. View: `ResultBanner` (`Shared/Views/ResultBanner.swift`, new)

A Walnut card (the `MoveListView(card: true)` / `EngineView` card styling, `Shared/Views/Walnut.swift`): an SF Symbol
(`crown.fill` for a win, `equal.circle.fill` for a draw) in the accent colour, the title in the player-name font
(`.serif`, semibold, headline size), the reason under it in `.footnote` secondary. `accessibilityElement(children:
.combine)`, identifier "result". Chrome, so it mirrors in he/ar (icon on the trailing side, text right-aligned); no
notation in it, so no `GameText.notation`.

Placement in `ContentView` (`Shared/Views/ContentView.swift`), the status line's slot, both layouts:
- tall (`tallLayout`, `:185-205`, both the tabletop and the flat branch): `ResultBanner` where `StatusLine` is when
  `session.result != nil`;
- wide (`sidebar`, `:145-152`, iPad, Duo inner landscape, Mac): the same, above the engine.
- `StatusLine` stays beside the banner only while browsing an earlier position (`!session.isAtLineEnd`): it then
  says whose move it is there; at the line's end it is hidden (the move strip already highlights the last move).
- The banner shows in every mode (play, analyze, train): the line's result does not depend on the mode.

No change to `PlayerRow` (D1 option B would add one), no alert (D4).

## Alternatives rejected

- **Result from the position on screen** (today's `gameEnd`): fails "stay visible while browsing".
- **Store the result in `GameState`** (a new field): a second source of truth beside the moves; breaks the I1 shape
  for no gain, since the result follows from the line (and from the PGN marker, already parsed into `outcome`).
- **Copy-free line end** (walk the node tree for the last move and test it): still needs a board and history to
  detect mate and repetition; the copy-and-replay is the existing, tested path.
- **Cache `result` per revision**: one line replay per read is cheap; add a cache only if a profile says so.
- **Writing `1/2-1/2` for automatic draws** (today `ChessGame::move` sets `draw` only for stalemate): correct but a
  PGN output change; left as a follow-up, the banner does not need it.

## Test plan (failing tests first)

Swift Testing, `BChessTests/GameSessionTests.swift` (production path: `GameSession(state:)` → `FEngine` →
`ChessEngine::lineResult`):
1. `resultForEachEnd` (parameterized): scholar's mate `1. e4 e5 2. Bc4 Nc6 3. Qh5 Nf6 4. Qxf7#` → white wins,
   checkmate; fool's mate (`Fixture.checkmate`) → black wins, checkmate; Loyd's ten-move stalemate → draw, stalemate;
   a repetition PGN (the one `noAnalysisWhenTheGameIsOver` uses) → draw, repetition; a FEN with half-move clock 99
   and one quiet move → draw, fiftyMoves; K+N v K FEN after a capture → draw, deadPosition; `1. e4 e5 1-0` → white
   wins, finished; `1. e4 e5 1/2-1/2` → draw, finished; an unfinished game → nil.
2. `resultStaysWhileBrowsing`: fool's mate, `move(to: .backward)` and `.start` → `result` unchanged, `gameEnd ==
   .none`, `isAtLineEnd == false`.
3. `aVariationHasItsOwnResult`: fool's mate, back one move, play another legal move → `result == nil`.
4. `readingTheResultKeepsTheRepetitionHistory`: a game one move short of a threefold repetition, browse back, read
   `result`, browse forward, play the repeating move → `gameEnd == .repetition` (fails if the copy shared the history).
5. `computerDoesNotPlayInADeadPosition` and `…AfterFiftyMoves`: a computer to move in each → no move requested
   (like `drawnPositionNeverPlaysAMove`, `:192`).

`BChessTests/GameTextTests.swift`: `resultTitles` and `resultReasons` (each winner and reason); `statusForGameEnds`
(`:85-93`) rewritten for the new mid-line statuses.

GoogleTest, `BChessTests/ChessEngineTests.cpp` (beside `GameEndCheckmate`, `:110-130`): `GameEndFiftyMoves`,
`GameEndDeadPosition`, `LineResultAtTheEnd`, `LineResultWhileBrowsing`. `FEngineTests.swift`: `lineResultCrossesTheBridge`.

Gallery (views are exempt from unit tests; every screen gets a scenario). Fixtures in `GalleryFixtures.swift` (added
to `allPGNs`, parse-checked by `GalleryScenarioTests`, which also asserts each one's `result`): `whiteMates`
(scholar's mate), `checkmate` (existing, black mates), `stalemate` (Loyd).
- iOS, `GalleryScenarios.swift`: "Game screen · White wins" and "Game screen · Black wins" (phone, tall),
  "Game screen · Draw" (stalemate), "Game screen · Result while browsing" (fool's mate, two moves back),
  "Game screen · Wide · White wins" (`.ipadLandscape`), "Duo inner · Landscape · Result" (`.duoInnerLandscape`,
  the wide layout), "Duo inner · Portrait · Tabletop · Result" (the tabletop branch); "Result banner · Draw" alone.
  `statusLineCheckmate` is removed (the status line no longer says it).
- Mac, `MacGalleryScenarios.swift`: "Document window · White wins" and "Document window · Draw".
- Light and dark are automatic. Right to left: `scripts/snapshot-gallery.sh --only "Game screen · White wins|Game
  screen · Black wins|Game screen · Draw|Result banner" --lang he,ar` (plus `--device ipad`, `--device duo`), and
  `scripts/snapshot-mac.sh --lang he,ar`; the board region compared with the English capture (`magick compare
  -metric RMSE`, 0), as AGENTS.md's Right to left section says.

The landing gate runs the macOS, UCI and iOS gates in `gates.md`, the gallery gate (iPhone, iPad, Duo, Mac) and the
catalog check.

## Invariants

- **I1 — Files keep opening:** holds. PGN reading and writing are unchanged (the Result tag still follows `outcome`);
  `GameState` is unchanged. Behaviour change only: an old game whose end position is past fifty moves or dead now
  shows a draw and the computer does not move there (D3).
- **I2 — Search results land only on their position:** holds. `result` is computed synchronously on the main thread
  from the engine's game, like `gameEnd`; no search involved.
- **I3 — Portable engine:** holds. Plain C++ in `ChessEngine.hpp`.
- **I4 — UCI tool:** holds. `BChessUCI` does not call `gameEnd`/`canPlay`; `MinMaxSearch` is untouched.
- **I5 — Private and offline:** not applicable.

## Risks and rollout

- File-format compatibility: none (see I1).
- The game copy in `lineResult` must use a fresh history (test 4 guards it).
- `outcome` is one per game, not per line (pre-existing): the end of a variation in a game loaded with `1-0` reads as
  a declared white win. Kept; noted.
- Real device: the banner on the smallest iPhone and in the Duo tabletop pose, Hebrew/Arabic on a device; owed.
- **#61 coordination:** #61 removes duplicate turn and last-move text and moves the board down. After APP-13 the
  result is said once, in the banner in the status line's slot; #61 must keep `ResultBanner` as the only game-over
  indication (no "wins" beside a player name, no "Last:" at the line's end), and if it drops or moves `StatusLine`,
  the banner takes that slot. `GameResult` and `isAtLineEnd` are there for #61 to reuse.

## Steps

1. **Engine and bridge** — `GameEnd.fiftyMoves`/`.deadPosition`, `ChessEngine::lineResult()`, the bridge enum and
   properties; GoogleTests and `lineResultCrossesTheBridge` first.
2. **Model** — `GameResult`, `GameSession.result`/`isAtLineEnd`, `GameText.resultTitle`/`resultReason`, the trimmed
   `status`; Swift tests 1–5 and the GameText tests first; strings in the catalog in all six languages
   (`catalog-sync`, stale keys deleted), `LocalizationExpectations`.
3. **Banner and layout** — `ResultBanner`, `ContentView` placement in both layouts, `StatusLine` hidden at the line's
   end.
4. **Gallery** — fixtures, iOS (iPhone, iPad, Duo) and Mac scenarios, `statusLineCheckmate` removed; light/dark and
   he/ar runs with the board compared.

## Decisions (Jean, 2026-11-21)

Jean chose the recommended option for each, after seeing mockups:

- **D1 — Visual form:** a result banner card in the status line's slot (icon, "White wins", "Checkmate").
- **D2 — Who won:** by colour ("White wins" / "Black wins" / "Draw").
- **D3 — Fifty moves and insufficient material:** both end the game automatically as a draw; the computer stops.
- **D4 — One-time announcement:** none; the banner appears with the final move and stays.
- **D5 — While browsing earlier moves:** the banner stays, and the status line comes back under it for the position on screen.

## Decision left open for Jean

None.
