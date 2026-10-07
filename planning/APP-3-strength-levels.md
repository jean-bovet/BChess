# APP-3 — Strength levels and the New Game sheet

Revision 3 (2026-10-07), accepted by Jean with D1–D4 as recommended (see §9). Planned in the worktree `.claude/worktrees/app-3-strength-levels` (branch
`app-3-strength-levels`, from `main` 278d1bf), against the search as ENGINE-3 search
(`planning/ENGINE-3-search.md` r3 on branch `engine-3-search`, steps 1–4 committed) will leave it.

- r1 — first draft.
- r2 — Codex plan round 1 (substantive). All eight findings were accepted (see "Review round 1 (Codex)" at the end):
  - The handicapped search has its own table.
  - White-relative scores are used correctly for Black.
  - Mate scores are no longer clamped.
  - The terminal root is defined.
  - The delay has a test seam.
  - The UCI gate runs synchronously.
- r3 — Codex plan round 2 (no blockers). All three should-fixes were accepted (see "Review round 2
  (Codex)"):
  - The node count includes the root moves.
  - `selDepth` and `movesPerSecond` are filled in.
  - The depth is a nominal cap, tested with a forcing line.
  - Calibration gets a clock policy and distinct names in self-play.

Jean's decisions (2026-10-07), which this plan does not reopen:

- **Six opponents in a ladder.** "A friend" (two humans on one device) and five computer strengths:
  Beginner (about 600), Casual (about 1000), Club (about 1400), Strong (about 1700) and Maximum
  (about 1950, the full engine).
- **Strength comes from handicaps, not from time.** The handicaps are:
  - a depth cap;
  - randomness among the top root moves, scaled by level;
  - occasional tactical blindness at the low levels.
- **The Elo numbers are targets.** Measuring them waits until ENGINE-3 search is done. This plan writes
  the calibration method down (§8) but does not run it.
- **No pace setting below Maximum.** The computer replies after a short natural delay. Maximum offers
  a thinking time of 5 s, 10 s or 30 s, which is the engine's real thinking time.
- **Old levels lose their meaning.** The old `GamePlayer.level` values 0–3 meant 2/5/10/15 s. Every old
  `.json` and `.pgn` file must still open (I1).
- **The sheet is design "C · Opponent ladder"** on iPhone and Mac (the approved mockups
  `NewGameLadder.dc.html` and `NewGameMac.dc.html`). It replaces `NewGameView` and `NewGameView_iOS`,
  including "Players & Level".

## 1. Problem, with evidence

- **The only setting is time, and it makes little difference to the opponent.** `GamePlayer.level`
  (`Shared/Model/GameState.swift:22`) maps to 2, 5, 10 or 15 seconds (`GamePlayer.thinkingTime`,
  `Shared/Model/GameSession.swift:44-55`). This is passed to `engine.thinkingTime`
  (`GameSession.swift:477`). Every level is the full engine: 1945 ± 39 on Stockfish's scale at 10+0.1
  after ENGINE-3 speed (`planning/README.md`). Even the 2-second level is far beyond a beginner.
- **The computer always plays the same game.** The search is deterministic. The opening book always
  plays the first continuation it has (`ChessOpenings::best`, `Shared/Engine/Engine/ChessOpenings.cpp:64-81`
  takes `opening.nextMoves[0]`). So the same moves by the human get the same replies.
- **The engine has no notion of strength.** `ChessEngine::searchBestMove`
  (`Shared/Engine/Engine/ChessEngine.hpp:200-210`) runs `IterativeDeepening::search` to a depth and a
  time. Nothing scores the root moves against each other, and the code has no random number generator.
- **The sheets ask for the wrong things.** `NewPlayerConfigurationView` (`Shared/Views/NewGameView.swift:11-31`)
  asks each colour for a name, a "Computer" toggle and a level in seconds. `NewGameView` (Mac,
  `:34-73`) and `NewGameView_iOS` (`Shared/Views/NewGameView_iOS.swift`) are two sheets of the same
  form. Neither looks like the Walnut screen (`Shared/Views/Walnut.swift`).
- **The level shows as seconds.** The player row reads "Black · 5 s" (`GameText.sideDetail`,
  `Shared/Model/GameText.swift:41-50`). The title and the status line say "Computer"
  (`GameText.name`, `:13-25`). `GameText.detail(of:toMove:)` (`:32-37`) has no caller left outside
  its test (`BChessTests/GameTextTests.swift:37-42`).
- **A new game never faces the player's way.** `GameShell.createGame` (`Shared/Model/GameShell.swift:69-76`)
  always builds `rotated: false`, so a player who takes Black sees the board from White's side.

## 2. Design

### 2.1 Overview and file map

| Area | New / changed | Deleted |
|---|---|---|
| Engine (portable C++) | `Shared/Engine/Algorithm/Handicap.hpp`: `Strength`, the handicap table, `chooseRootMove`, `HandicappedSearch`. `ChessEngine`: a `strength` argument to `searchBestMove`, and a random generator | — |
| Bridge | `EngineStrength` (`NS_CLOSED_ENUM`), `FEngine.strength`; book and time only at Maximum | — |
| UCI tool | `option name Strength`, `setoption name Strength value …` | — |
| Model (pure, tested) | `GamePlayer.strength`, `thinkingTime`, `computer(_:thinkingTime:)`; `Shared/Model/NewGame.swift`; `GameText` wording; `GameSession` strength and reply delay; `setPlayers(…, rotated:)`; `GameShell.createGame(…, rotated:)` | `GameText.detail(of:toMove:)` |
| Views | `Shared/Views/NewGameSheet.swift` (iPhone and Mac) | `NewGameView.swift`, `NewGameView_iOS.swift` (with `NewPlayerConfigurationView`) |
| Shells | `iOS/GameRootView.swift`, `macOS/DocumentWindow.swift`, `macOS/GameCommands.swift`: the new sheet, "Players…" | — |

### 2.2 The levels and their handicaps (engine)

One table, in `Handicap.hpp`, is the only place the levels are tuned. The values below are starting
values, chosen by reasoning and not yet measured. Calibration (§8) changes this table and nothing else.

| Strength | Root moves searched to depth | Temperature (cp) | Blindness |
|---|---:|---:|---:|
| Beginner | 1 | 150 | 0.5 |
| Casual | 2 | 60 | 0.2 |
| Club | 3 | 25 | 0 |
| Strong | 5 | 8 | 0 |
| Maximum | — (today's search, by time) | — | — |

```cpp
enum class Strength { beginner, casual, club, strong, maximum };

struct Handicap {
    int depth;          // each root move is scored by a search of depth - 1 after it
    int temperature;    // centipawns: how readily a move below the best is played
    double blindness;   // the chance that a move is chosen with no quiescence search
    static Handicap of(Strength strength);   // not called for maximum
};
```

**How a handicapped move is chosen** (`HandicappedSearch::search(IterativeDeepening &, board, history,
Handicap, std::mt19937_64 &)`):

1. **Blindness is drawn once per move.** With probability `blindness`, the move is chosen with
   `minMaxSearch.config.quiescenceSearch = false`, an existing flag (`MinMaxSearch.hpp`
   `Configuration`). The flag is restored afterwards. Without quiescence, the horizon takes material
   at face value. So the engine grabs defended pawns and leaves pieces hanging. The depth is a
   **nominal** cap, not a horizon on mates:
   - ENGINE-3's quiescence searches captures, and every evasion when in check (quiet ones included).
   - So at depth 1 a forcing line of capture-checks can still be followed past the cap.
   - "Misses mates" in the blurb therefore comes from the shallow cap on quiet mating moves and from
     blindness (which turns quiescence off), not from a guarantee. Calibration measures how this plays
     out.
2. **Its own transposition table.** Each handicapped search uses a fresh local
   `TranspositionTable table(1)` (1 MB, allocated on its first store and freed on return). It never
   reads or writes `IterativeDeepening::table` (review r1, finding 3). This matters for two reasons:
   - `TranspositionTable::exists` ignores the generation.
   - `MinMaxSearch` stores values even when `config.transpositionTable` is false.

   Without its own table, deeper entries from a Maximum analysis would lift the depth cap. Values
   computed without quiescence (a blind move) would also leak into the next full-strength search or
   the next handicapped move. A fresh 1 MB table per move costs nothing measurable. The killers are
   cleared at the start, as `IterativeDeepening::search` does.
3. **Every legal root move is scored by the engine's own search.** The loop works like this:
   - The root moves come from `ChessMoveGenerator::generateMoves`.
   - For each move, the child board is made and its hash is pushed on the history, as
     `alphabeta`'s own loop does.
   - The child is scored by the **public** `MinMaxSearch::alphabeta(child, history, table, /*ply*/ 1,
     child.color == WHITE, pv, emptyLine)`, with `config.maxDepth = depth − 1`. `depth − 1 = 0`
     means quiescence only. Ply 1 makes the child subject to the repetition and fifty-move checks
     (`ply > 0 && drawnByPath`). It also makes mate distances count from the real root.
   - The hash is popped.
   - **The score is White-relative.** The public `alphabeta` returns `score * color`, as
     `IterativeDeepening::search` stores it. That value is kept as is for `ChessEvaluation.value`. For
     the choice only, it is multiplied by the **root's** colour (+1 White, −1 Black), giving the side
     to move's point of view (review r1, finding 1).
   - **Each score is the search's value at a nominal depth, not an exact minimax value.** The child
     search is whatever ENGINE-3 ships (finding 5): check extensions make the depth nominal, and null
     move, LMR, futility and SEE pruning apply below the child as in any search. That is intended,
     because the levels are "the engine, handicapped". Step 1 records which ENGINE-3 options are on
     in the landed configuration, and calibration (§8) measures the result as it is.
   - This is MultiPV for all moves by brute force. It costs about `N × cost(depth − 1)`, which is small
     at depth ≤ 5. The siblings share the local table.
4. **The choice** is a pure function, `int chooseRootMove(const std::vector<int> &scores, int
   temperature, double u)`. The scores are from the side to move's point of view, raw and **not
   clamped**, and `u` is in [0, 1). The vector is never empty: the wrapper handles a root with no move
   before it is called (step 6).
   - A move is a candidate when its score `s` satisfies `s ≥ best − 4·temperature`. Its weight is
     `exp((s − best) / temperature)`.
   - Mate scores (±`MAT_VALUE` ∓ plies) sit far beyond any window, so they need no special rule
     (findings 2 and 4):
     - When a mate is found, only mates are candidates. Mates within `4·temperature` plies of each
       other compete, and any of them wins.
     - A move that walks into a forced mate is never chosen while a move that is not mated exists,
       however bad that move is (−1200 beats −MAT+2).
     - A large advantage keeps its order: +1200 is never traded for +300 at Club.
   - The differences are computed in `int`. They are at most about 2·`MAT_VALUE`, so they cannot
     overflow.
   - `u` picks along the cumulative weights. With the same scores and the same `u`, the result is
     always the same, which makes it testable.
5. **The result.** It is a `ChessEvaluation` shaped like the one `IterativeDeepening::search` returns:
   - `line` is the chosen move followed by its child PV;
   - `value` is the child's White-relative score, unchanged;
   - `depth` is the handicap depth;
   - `selDepth` is the deepest `minMaxSearch.maxPly` seen over the children;
   - `nodes` is the number of root moves searched plus the sum of `visitedNodes` over the children.
     `visitedNodes` counts only moves made inside `alphabeta` and quiescence. At Beginner from the start
     position every child is a static evaluation with no capture to search, so the sum alone is 0
     (review r2, finding 1);
   - `time`, `movesPerSecond` (`IterativeDeepening::nodesPerSecond`) and `engineColor`.

   UCI prints all of these in its `info` line.
6. **A root with no move.** With checkmate or stalemate, `generateMoves` is empty (finding 8). The
   wrapper then returns an evaluation with an empty `line`, like `IterativeDeepening` on such a root.
   The bridge reports `hasBestMove == false`, the session plays nothing (`searchDidUpdate`'s existing
   guard), and UCI prints `bestmove 0000` (`FENgineInfo+Extension.swift:40`).

   A root that is already drawn by rule but has legal moves (threefold, fifty-move) is still searched.
   The root itself is never drawn, its children score 0 where the rule applies, and a move is returned.
7. **Stop and cancel.** The loop checks `IterativeDeepening::cancelled()` after each child and returns
   with no move when it is set. `searchBestMove`'s existing `!iterativeSearch.cancelled()` guard then
   suppresses the callback. A `stop()` does not cut a handicapped search short: `completedDepth`
   stays 0, so `IterativeDeepening::stop` never cancels `minMaxSearch`. The bounded search always
   finishes and returns a real move, also under UCI `stop`. At the end, the status goes from running to
   stopped, as `IterativeDeepening::search` does (`compare_exchange_strong`).

**`ChessEngine` changes.** `ChessEngine` gains
`std::mt19937_64 random{std::random_device{}()}` and `void seedRandom(uint64_t)`, which only the tests
call. `searchBestMove(board, history, maxDepth, transpositionTable, Strength strength, callback)`
works like this:

- At Maximum it is exactly today's path, so the bench signature cannot change.
- At any other strength it runs `HandicappedSearch` and calls the callback once, with `done = true`.
  `maxDepth` and the timer are ignored.
- The generator is used only on the search queue: searches on one engine never overlap
  (`FEngine.mm:43-50`).

**The search code is not edited.** `HandicappedSearch` uses only:

- `MinMaxSearch::alphabeta` (public), `config.maxDepth` and `config.quiescenceSearch`, `reset`,
  `clearKillers` and `visitedNodes`;
- `IterativeDeepening::status` and `cancelled`;
- a `TranspositionTable` of its own.

ENGINE-3's step 10 adds an `alphabeta` overload but keeps this one. Step 6's `pvNode` is internal, and
the public entry is a PV node. Steps 5 and 7–12 make each child search stronger, which is why
calibration waits for them (§8).

### 2.3 Bridge and UCI

- `FEngine.h`: `typedef NS_CLOSED_ENUM(NSInteger, EngineStrength) { EngineStrengthBeginner = 0,
  …Casual, …Club, …Strong, …Maximum };` and `@property EngineStrength strength` (default Maximum).
  `evaluate:time:callback:` captures it like `ttEnabled` and passes it to `searchBestMove`.
- **The opening book is used only at Maximum.** In `evaluate:time:callback:`, the book lookup runs when
  `useOpeningBook && strength == EngineStrengthMaximum`. The lower levels open with their own
  randomness, so their games do not repeat. This rule sits in the bridge because it has two callers,
  the app and `BChessUCI` (D2).
- `BChessUCI` (`BChess/UCI/UCI.swift`):
  - On `uci`, it prints `option name Strength type combo default Maximum var Beginner var Casual var
    Club var Strong var Maximum` before `uciok`.
  - `setoption name Strength value <name>` sets `engine.strength`. An unknown value is ignored and logged,
    and stdout stays clean.
  - The other `setoption`s are still ignored.
  - Calibration (§8) needs this option, and so does anyone who wants a weak BChess in a GUI.

### 2.4 The model: `GamePlayer.level`, kept as the file format

The JSON shape is unchanged: `{"name", "computer", "level"}`. Only the meaning of `level` changes.

| `level` | Meaning | Old meaning (ignored) |
|---|---|---|
| 0 | Beginner | 2 s |
| 1 | Casual | 5 s |
| 2 | Club | 10 s |
| 3 | Strong | 15 s |
| 4 | Maximum, 5 s | — |
| 5 | Maximum, 10 s | — |
| 6 | Maximum, 30 s | — |
| other | Club | 2 s |

In `GameState.swift`, beside `GamePlayer`:

- `var strength: EngineStrength`;
- `var thinkingTime: TimeInterval`, which is 5, 10 or 30 at Maximum and 0 otherwise;
- `static func computer(_ strength: EngineStrength, thinkingTime: TimeInterval = 10) -> GamePlayer`,
  the only writer of the new values.

The old `thinkingTime` extension in `GameSession.swift:44-55` is deleted. `defaultBlack` becomes
`.computer(.club)`, so a Mac window whose sheet was cancelled plays the Club player. An old file
decodes as before (I1). Its computer becomes Beginner…Strong, which is "anything sensible" (Jean). A
file with no `black` key gets Club.

### 2.5 The session: strength, analysis at full strength, a natural delay

`GameSession.requestEngineMoveIfNeeded()` (`GameSession.swift:455-489`):

- It sets `engine.strength = player.strength`, and `engine.thinkingTime = player.thinkingTime` (used
  only at Maximum). `useOpeningBook = true` stays, and the bridge applies it only at Maximum.
- It records `replyNotBefore`, a `ContinuousClock.Instant`:
  - below Maximum, `now + .seconds(Double.random(in: replyDelay))`;
  - at Maximum, `now`, where the engine's time is the wait.

  `var replyDelay: ClosedRange<TimeInterval> = 1.0...2.5` is a seam for the tests, like
  `analysisBudget` (D3).
- The delay is measured from the start of the search. A search that took 1.5 s waits only for what is
  left. The Strong level on a slow phone may take longer than the delay, and then it waits for nothing.

`searchDidUpdate(_:completed:token:)` (`:543-560`) handles a completed result with a move in two cases:

- **The wait is over** (`replyNotBefore <= now`). It plays as today.
- **The wait is not over.** It hands the reply to
  `@ObservationIgnored var scheduleReply: @MainActor (_ after: TimeInterval, _ reply: @escaping @MainActor () -> Void) -> Void`.
  - By default this is
    `DispatchQueue.main.asyncAfter(deadline: .now() + after) { MainActor.assumeIsolated(reply) }`.
  - Tests replace it to capture the block and run it when they choose, so they need neither timing
    nor inference (finding 6). This is the same seam shape as `animate`.
  - The block checks `token == positionID` again, then runs the same `perform(animated: play…)`.
  - `isThinking` stays true during the wait, so the status line says "… is thinking…".
  - The main thread never waits. Any position, player or mode change bumps `positionID` and drops the
    pending reply. This is the same authority for I2 as today, applied once more after the wait.

`analyzeIfNeeded()` (`:512-529`) sets `engine.strength = .maximum` before `evaluate`. Analysis always
runs at full strength, whoever the opponent is. Without this, the analysis would inherit the last
computer search's handicap.

`setPlayers(white:black:rotated: Bool? = nil)`: the Mac's new window applies the sheet's players and
orientation as **one** state change, so they make one undo step. `nil` keeps the rotation, and the
edit mode passes `nil`. `GameShell.createGame(white:black:rotated:discardingUnsavedChanges:)` passes
the orientation into `GameState(pgn:rotated:white:black:)`.

Computer against computer stays in the model. `computerVersusComputerContinues` keeps passing, and old
files with two computers open and play. The sheet no longer offers it (D4).

### 2.6 `NewGame` — the sheet's choices, pure (`Shared/Model/NewGame.swift`)

`NewGame` is Foundation-only, so `BChessTests` compiles it (`project.yml:125`). Both sheets read it,
which makes it a value with two callers, and the tests check it.

```swift
nonisolated struct NewGame: Equatable, Sendable {
    enum Opponent: Int, CaseIterable, Sendable { case friend, beginner, casual, club, strong, maximum }
    enum Side: Sendable { case white, random, black }
    var opponent = Opponent.club
    var side = Side.white
    var firstName = ""        // "Your name", or the first player's name against a friend
    var secondName = ""       // the friend's name
    var thinkingTime: TimeInterval = 10   // 5, 10 or 30; Maximum only
    init()
    init(white: GamePlayer, black: GamePlayer)   // the edit mode: the game's players
    func players(firstPlaysWhite coin: Bool) -> (white: GamePlayer, black: GamePlayer, rotated: Bool)
}
```

- **Per opponent,** from the mockups:
  - the name;
  - the blurb, where the friend's blurb is "Pass and play on this device" on iPhone and "Take turns on
    this Mac" on the Mac (`#if os(macOS)`);
  - the Elo text ("about 600" … "about 1950", empty for a friend);
  - the piece image: `pawn_w` for a friend, then `pawn_b`, `knight_b`, `bishop_b`, `rook_b`, `queen_b`
    (`Shared/Assets.xcassets/pieces`).
- **Labels.**
  - `sideLabel`: "You play", or "First player plays" against a friend.
  - `firstNameLabel`: "Your name", or "White", "Black" or "Random color" against a friend.
  - `secondNameLabel`: the other colour, or "Random color".
  - `playLabel`: "Play the Club Player", "Play the Full Engine" or "Start Game". This is the approved
    mockup's wording, and the same names are the computer's name on the game screen (§2.8, D1).
  - `showsThinkingTime`: true only at Maximum.
- **`players(firstPlaysWhite:)`.** `coin` resolves Random. The views pass `Bool.random()`, and the
  tests pass a fixed value.
  - Against the computer, the human `GamePlayer(name: firstName, computer: false, level: 0)` gets the
    chosen colour. The computer gets `.computer(strength, thinkingTime:)`.
  - Against a friend, `firstName` goes to the first player's colour and `secondName` to the other.
  - `rotated` is true when the first player has Black.
- **`init(white:black:)`, the edit mode.**
  - One computer: the opponent is its strength (with its thinking time at Maximum), the side is the
    human's colour, and `firstName` is the human's name.
  - Two humans: a friend, White first, with both names.
  - Two computers (old games only): the opponent is Black's level, the side is White and the name is
    empty. Applying the sheet makes such a game "you against Black's level".

### 2.7 The sheet (`Shared/Views/NewGameSheet.swift`)

There is one view, `NewGameSheet(choice: NewGame, mode: .new | .edit, onDone: (NewGame) -> Void)`,
with two layouts under `#if os(iOS)`. It uses the Walnut tokens that the mockup's colours already are:

- `Walnut.background` #F4F1EC;
- `Walnut.card` and `cardBorder` #E4DCD1;
- `textPrimary` and `textSecondary`;
- `AccentColor` #8A4B22 for the selected row's 2 pt border;
- `pillBackground` #F2DFB8 for a computer's piece tile;
- `Walnut.scoreChip` and `scoreChipText` (#4A3222 on #F4E6CF) for the primary button;
- the serif names, as in `PlayerRow`.

The friend's tile and the segmented controls use `Walnut.background`. No colour set is added.

- **Rows.** The opponent list is six button rows: a 40 pt tile (32 pt on Mac), then the name, "about N"
  and the blurb. The selected row has `.isSelected`.
- **The Players card** (`walnutCard`) holds:
  - the side `Picker` (`.segmented`: White / Random / Black);
  - one or two name `TextField`s;
  - at Maximum only, "Thinking time" `Picker(.segmented)` 5 s / 10 s / 30 s, with "More time, stronger
    play." under it on Mac.
- **iPhone.** A `NavigationStack` with "Cancel" (leading) and the title "New Game", the list, the
  card, and the full-width primary button at the bottom.
- **Mac.** The title, the list (330 pt) on the left and the card's controls on the right, then Cancel
  (`.cancelAction`) and the primary button (`.defaultAction`) at the bottom right, as in
  `NewGameMac.dc.html`.
- **Edit mode** (D4) is the same sheet, titled "Players", with the button "Done". The side picker shows
  White and Black only, since flipping a coin in the middle of a game is not a choice.
- **The sheet remembers the last choice.** `@AppStorage` keeps `newGame.opponent`, `newGame.side`,
  `newGame.name` and `newGame.thinkingTime`, so a new game opens on the player's usual opponent and name.
  It defaults to Club, White and 10 s, as in the mockups. The edit mode starts from the game instead.
- **Callers.**
  - iPhone `GameRootView`: the ⋯ menu has "New Game" and "Players" (was "Players & Level").
    `PendingSwitch.create` carries `rotated`. Done in edit mode calls `session.setPlayers(white:black:)`
    and `requestEngineMoveIfNeeded()`, as the old OK did.
  - Mac `DocumentWindow`: the sheet is offered once for a new document (unchanged), in `.new` mode.
    Its button calls `setPlayers(white:black:rotated:)` and then `requestEngineMoveIfNeeded()`, so a
    computer with White plays at once. Game ▸ "Players…" opens it in `.edit` mode. The
    `focusedSceneValue` gating stays.
- `#Preview`s: new on iPhone at Club, a friend, Maximum, edit mode, and the Mac layout.

### 2.8 Wording elsewhere (`GameText`)

- `name(of:)` for a computer with no name is "Beginner Player", "Casual Player", "Club Player",
  "Strong Player" or "Full Engine", the button's words (D1). This gives the title "You vs Club Player"
  and the status "Club Player is thinking…". A player's own name still wins.
- `sideDetail` for a computer is "Black · Club", or "Black · 10 s" at Maximum, where the time is the
  setting (D1).
- `detail(of:toMove:)` is deleted with its test, because nothing calls it.

### 2.9 Reuse

- **Search.** `MinMaxSearch::alphabeta` (public), `Configuration::quiescenceSearch` and `maxDepth`,
  `IterativeDeepening` `status` and `cancelled()`, `TranspositionTable` (a local one per handicapped search),
  and `ChessMoveGenerator::generateMoves`.
- **Mates.** The search's mate scores (`ChessEvaluater::MAT_VALUE` minus plies), used as they are by the
  choice.
- **Threading.** The bridge's generation guard and search queue (`FEngine.mm:43-50`, `:333-389`), and
  the `ttEnabled` capture pattern for `strength`.
- **The I2 authority.** `GameSession.positionID` and `searchDidUpdate`'s token, which are applied once
  more after the delay. The `analysisBudget` seam pattern for `replyDelay`.
- **The file format.** `GamePlayer.level`, keeping its key and type.
- **The model and the UI.** `GameShell.createGame`, `PendingSwitch.create`, `DocumentWindow`'s "offer
  the sheet once", the `focusedSceneValue(\.showPlayers)` command routing, `Walnut` tokens and
  `walnutCard`, and the piece image sets.
- **Calibration.** `scripts/elo-match.sh` (Stockfish `UCI_Elo` and A/B modes) and `docs/elo.md`.

## 3. Alternatives rejected

- **Noise in the evaluation** (a random term per leaf). It touches the evaluator and the table's
  values, and it plays erratic moves rather than "a slightly worse move among good ones". It also
  cannot make a single move blind.
- **MultiPV inside `alphabeta`** (excluded root moves, Stockfish's Skill Level). It edits the search
  that ENGINE-3 is changing step by step, and it gives only the top K. Scoring every root move from
  outside, at depth ≤ 5, costs little and does not touch the search.
- **Strength by time or by node count.** Jean ruled time out. A node cap makes the strength depend on
  the device's speed less than time does, but still on the position. A depth cap is the same on every
  device.
- **A new JSON key for the strength or the thinking time.** It changes the file format for nothing,
  since one `Int` holds all seven choices and Jean let the old values go.
- **Keeping the book at every level.** The book plays the first line it has, so every game below
  Maximum would open the same way. Picking a random book move would need a `ChessOpenings` change (D2).
- **The delay in the bridge.** The UCI tool must answer as fast as it can (I4), and the delay is
  presentation. The session already owns the I2 token that must survive it.
- **Two sheet views again, one per platform.** The rows, the card and the rules are shared. Only the
  outer layout differs, and `#if os(iOS)` covers it.

## 4. Test plan

Every test is written red first. A new `.cpp` file in `BChessTests/` is picked up by the folder source
(`project.yml:121`), and `EngineGoogleTests.registersAllCases`' floor is raised by the number of cases
added.

**GoogleTest, `BChessTests/HandicapTests.cpp`:**

| Test | Proves |
|---|---|
| `HandicapTests.ChooseNeverPlaysOutsideTheWindow` | scores {100, 90, −300}, temperature 25, u over a grid of 1000 values in [0, 1): index 2 is never returned |
| `HandicapTests.ChooseSpreadsEqualMoves` | scores {0, 0, 0}: every index is returned for some u |
| `HandicapTests.ChooseIsDeterministic` | the same scores and u give the same index |
| `HandicapTests.AFoundMateIsAlwaysPlayed` | {MAT−1, MAT−3, 1200, 0 × 20}: at every level's temperature, every u returns one of the two mates |
| `HandicapTests.AForcedLossIsNeverChosen` | {−MAT+2, −1200}: every u returns index 1, at every level |
| `HandicapTests.ALargeAdvantageKeepsItsOrder` | {1200, 300}: at Club and Strong every u returns index 0 |
| `HandicapTests.ClubTakesAHangingQueen` | a position with a free queen: over 20 seeds, Club always captures it |
| `HandicapTests.BlindnessPlaysTheCaptureQuiescenceRefuses` | depth 1, blindness 1.0 (a `Handicap` literal) takes a pawn defended by a pawn; blindness 0.0 never does. So the flag is used |
| `HandicapTests.CasualVariesFromTheStart` | the start position, 10 seeds: at least 2 different moves |
| `HandicapTests.ARepeatingMoveScoresADraw` | a root move that makes a threefold repetition is scored 0 (the child is searched at ply 1) |
| `HandicapTests.BlackChoosesBlacksBest` | Black to move with a free queen to take, Club, 20 seeds: always the capture; `value` is negative (White-relative, as `IterativeDeepening` reports it). Fails if the root colour is not applied, or applied twice |
| `HandicapTests.NoMoveAtCheckmateOrStalemate` | a mated root and a stalemated root: an empty `line`, and the callback is still called once with `done` |
| `HandicapTests.ARuleDrawnRootStillPlays` | a root at half-move clock 100, and a root that has already occurred three times, both with legal moves: a legal move is returned |
| `HandicapTests.DeepEntriesDoNotLiftTheCap` | a depth-8 Maximum search of a position, then a Club search of it with seed s, gives the same move, value and nodes as a Club search with seed s on a fresh engine |
| `HandicapTests.BlindValuesDoNotReachMaximum` | a blind Casual search (blindness 1.0), then a depth-5 Maximum search, gives the same move, value and nodes as that Maximum search on a fresh engine |
| `HandicapTests.ResultIsShapedLikeTheSearch` | `line[0]` is legal and is the chosen move, `depth` is the handicap depth, `value` is from White's point of view; at Beginner from the start position `nodes >= 20` (the root moves) and `selDepth >= 1` |
| `HandicapTests.QuiescenceFollowsForcingLinesPastTheCap` | at Beginner depth with blindness 0, a position with a mate reached only through capture-checks beyond the cap: the child of the first move scores as a mate. With blindness 1.0 it does not. This pins down what the nominal cap means (finding 2) |
| `HandicapTests.MaximumIsTheIterativeSearch` | `searchBestMove(…, Strength::maximum, …)` returns the same move and value as `iterativeSearch.search` at depth 4 |

**Swift Testing:**

| Test (file) | Proves |
|---|---|
| `handicappedSearchSkipsTheBook` (`FEngineTests`) | from the start position with `useOpeningBook`, Beginner reports `nodes > 0` and Maximum answers from the book |
| `cancelStopsAHandicappedSearch` (`FEngineConcurrencyTests`) | parked with `setSearchCheckpoint`, then cancelled and released: no callback. Fails without the `cancelled()` check |
| `stopFinishesAHandicappedSearch` (`FEngineConcurrencyTests`) | `stop()` right after `evaluate` still delivers a completed result with a move |
| `strengthOptionIsAnnounced`, `setoptionSetsTheStrength`, `unknownStrengthIsIgnored`, `handicappedMateAnswersNullMove` (`UCICommandTests`) | the `uci` output has the option line before `uciok`; `setoption name Strength value Club` sets `.club`; a bad value leaves it unchanged and prints nothing; at Beginner, `go` on a mated position prints `bestmove 0000` |
| `oldLevelsStillOpen` (`GameStateCodingTests`) | the legacy JSON with levels 1 and 3 decodes as Casual and Strong; a level of 9 decodes as Club; levels 4–6 round-trip with 5/10/30 s |
| `strengthAndTimeFollowTheLevel` (`GameTextTests` or new `GamePlayerTests`) | the table in §2.4 |
| `computerNamesAndDetails` (`GameTextTests`, replaces the seconds test) | for every level: the name ("Beginner Player" … "Strong Player", "Full Engine"), the title ("You vs Club Player", "Full Engine vs You"), the status ("Club Player is thinking…") and the row detail ("Black · Beginner" … "Black · Strong", "White · 5 s" and "White · 30 s" at Maximum); a given name wins |
| `NewGameTests` (new file): `playersAgainstEachLevel`, `randomSideUsesTheCoin`, `friendNamesFollowTheFirstPlayersColor`, `rotatedWhenThePlayerHasBlack`, `thinkingTimeOnlyAtMaximum`, `labelsFollowTheMockups`, `editReadsTheGamesPlayers`, `editOfTwoComputersBecomesYouAgainstBlack` | §2.6 |
| `searchUsesThePlayersStrength` (`GameSessionTests`) | after `requestEngineMoveIfNeeded`, `engine.strength` is the side to move's strength |
| `analysisIsFullStrength` (`GameSessionTests`) | a Beginner reply, then the readout on during the human's turn: `engine.strength == .maximum` |
| `computerWaitsBeforeReplying` (`GameSessionTests`) | Beginner, `replyDelay = 60...60`, `scheduleReply` capturing. A human move is played and the test waits until a reply has been captured, which proves the search completed. No move is played yet and `isThinking` is true. Running the captured block plays the reply |
| `aDelayedReplyIsDroppedOnPositionChange` (`GameSessionTests`, parameterized) | the I2 test. With the reply captured as above, one of these runs before the block: Back, `toggleAnalyze`, `setPlayers` (both human), `paste` of a FEN, `cancelSearch` (what `GameShell.install` calls when it replaces the session). Then the captured block runs, and nothing is played. Fails if the block skips the token check |
| `maximumRepliesWithoutDelay` (`GameSessionTests`) | Maximum with `replyDelay = 5...5`: the book reply is played within 1 s |
| `createGameKeepsTheOrientation` (`GameShellTests`) | `createGame(…, rotated: true)` saves and installs `rotated == true` |
| `setPlayersWithRotationIsOneChange` (`GameSessionTests`) | `setPlayers(…, rotated: true)` changes `gameState` once (one observed value) |

**Existing tests that change meaning:** `computerBlack` (`GameSessionTests.swift:15`) and the level-0
computers relied on the book and a 2-second search. They become `.computer(.maximum, thinkingTime: 5)`
(level 4). The sleeps that assumed 2 s, such as `cancelledSearchNeverPlaysItsMove` at `:714`, are
re-timed. The suite's sessions set `replyDelay = 0...0` unless a test is about the delay.
`thinkingTimeFollowsSideToMove` (`:735`) is rewritten for levels 4 and 6 (5 s and 30 s).

## 5. Steps (one commit each; each passes every gate in `/develop`)

Each step's gate is the three `xcodebuild` commands plus the two zero-warning builds, with every
GoogleTest case executed.

1. **Engine: handicapped search.** Adds `Handicap.hpp` (the table, `chooseRootMove`,
   `HandicappedSearch`), the strength argument and the generator in `ChessEngine`, `HandicapTests.cpp`,
   and the raised floor. The bridge passes `Strength::maximum` for now.
   - Extra gate: `scripts/bench.sh` at depth 6 (one short run, the default) gives a signature identical
     to the base commit's. This proves Maximum is untouched.
2. **Bridge and UCI.** Adds `EngineStrength`, `FEngine.strength`, the book only at Maximum, the UCI
   option, and the `FEngineTests`, `FEngineConcurrencyTests` and `UCICommandTests` cases.
   - Extra gate: `BChessUCI xcode '||' uci '||' setoption name Strength value Beginner '||' position startpos '||' go depth 3`
     prints the option line and a legal `bestmove`, then exits.
     - The `xcode` command makes the search synchronous (`engine.async = false`, `UCI.swift`), so
       `bestmove` is printed before the argument mode's `exit(0)`, with no race on `quit` (finding 7).
     - The same run on a mated FEN prints `bestmove 0000`.
3. **Model and session.** Adds the level table, `GamePlayer.strength`, `thinkingTime` and `computer`,
   `defaultBlack`, the `GameText` wording, the strength in the session, analysis at full strength, the
   reply delay, `setPlayers(…, rotated:)` and `createGame(…, rotated:)`. The fixtures are migrated as
   in §4.
4. **`NewGame`** and `NewGameTests`.
5. **The sheet.** Adds `NewGameSheet.swift` with its previews and wires it into the iPhone and Mac
   shells and the menus. Deletes `NewGameView.swift` and `NewGameView_iOS.swift`. Runs `xcodegen
   generate` and commits the project.
   - Extra gate: the previews render (the implementer runs them in Xcode or builds them).
   - Owed to Jean: the sheet seen on an iPhone and on a Mac.
6. **Record.** Updates the plan's results and the README row ("Implemented on main …", the owed device
   checks), and adds a line to `docs/elo.md` saying that the level numbers are targets until §8 is run.

## 6. Invariants

- **I1 — files keep opening.** Held: the JSON keys and types are unchanged, and the `.pgn` path is
  untouched (both players human). Old levels 0–3 decode as Beginner…Strong, and any other `Int` as
  Club. `oldLevelsStillOpen` pins this down. An older BChess opening a new file reads levels 4–6 as
  "2 s" (its `default`), which is harmless.
- **I2 — a result lands only on its position.** At risk from the delay, and held as follows:
  - the delayed block re-checks `positionID`, which every change bumps, so
    `aDelayedReplyIsDroppedOnPositionChange` proves it;
  - the handicapped search's callback goes through the bridge's unchanged generation guard;
  - `cancelStopsAHandicappedSearch` covers cancel during the root loop;
  - the main thread never waits, since the delay is `asyncAfter`.
- **I3 — the engine stays portable.** Held: `Handicap.hpp` uses `<random>`, `<vector>` and `<cmath>`
  only.
- **I4 — the UCI tool keeps working.** Held: the delay is in the app session only. The handicapped
  callback runs on the search queue like any other. `stop` still produces a `bestmove`
  (`stopFinishesAHandicappedSearch`).
- **I5 — private and offline.** Not applicable. `@AppStorage` is local.

## 7. Risks and rollout

- **The Elo labels are not yet measured.** The sheet says "about N" from day one, and the starting table
  could miss by hundreds of points until §8 is run. Jean accepted this, and `docs/elo.md` says so
  (step 6).
- **Strong's cost on an old phone.** It searches about 35 children at depth 4 after ENGINE-3's
  pruning. Expected: well under a second on an A15. If a device check shows several seconds, Strong
  drops to depth 4 with a smaller temperature, which is a table change. Owed: one Strong game on the
  oldest iPhone available.
- **Test timing.** Moving fixtures from the 2-second level to Maximum 5 s lengthens a few session tests
  by a few seconds. The delay seam keeps every other test at 0.
- **Rebase onto ENGINE-3.** `HandicappedSearch` relies on the public `alphabeta` signature with `ply`
  (ENGINE-3 search step 1) and on `ply > 0` draws (step 2). Both are on `engine-3-search` today.
- **Nothing in the file format can be undone.** Levels 4–6 written by APP-3 mean "Maximum" from now
  on, so any later change must keep them.

### Integration with ENGINE-3 search

**APP-3 starts after ENGINE-3 search lands on `main`.** The worktree is then rebased (this plan is
docs-only, so the rebase is trivial). Basing it on `engine-3-search` instead is not better, for three
reasons:

- that branch's steps 5–12 are SPRT-gated and may be dropped or reworked, so APP-3 would rebase
  repeatedly;
- the shared machine is busy with those SPRTs, and APP-3's test runs would compete with them;
- the two reviews would mix.

The engine part touches no search file, so the overlap is limited to `ChessEngine.hpp`'s
`searchBestMove` and `EngineGoogleTests`' floor.

If Jean wants the UI sooner, steps 3–5 depend only on `FEngine.strength` existing. Steps 1–2 could
also land on today's `main` if the call uses today's public `alphabeta` (no `ply`). But the child would
then be searched as a root, with no repetition check and mate distances off by one. That is a real
downgrade, so this plan does not recommend it.

## 8. Calibration method (a later, separate step — not part of this implementation)

It runs once ENGINE-3 search is on `main` and APP-3 has landed, on an idle machine. The method:

1. **`scripts/elo-match.sh` gains two variables.**
   - `STRENGTH=<name>` adds `option.Strength=<name>` to the BChess engine.
   - `OPPONENT_STRENGTH=<name>` is a self-play mode: BChess at `STRENGTH` against the same binary at
     `OPPONENT_STRENGTH`.
   - **Names.** In self-play only the measured side is named `BChess`, and its opponent is named
     `BChess-<level>`. `pgn_summary` identifies the measured side by the literal name `BChess`, so two
     engines named `BChess` would count every decisive game as a loss (review r2, finding 3).
   - **Validator fixtures.** The script's existing fixtures gain self-play games with the measured
     level as White and as Black, and a fixture where both sides are named `BChess`, which must be
     reported as malformed.
   - **The clock.** A handicapped level ignores the clock, but its search is mandatory and is not cut
     by time. So the time control is chosen from measured runtimes, and the length of a short time
     control is not assumed:
     - first, a 20-game timing probe at the Strong level records the longest move;
     - the TC's base and increment are then set so that 80 times the longest move fits, with margin;
     - `TIMEMARGIN` is kept generous.

     `judge_run` rejects any run with a time forfeit by either engine. Such a run is redone at the next
     longer control, never accepted.
2. **Maximum.** It keeps the published 10+0.1 figure (`docs/elo.md`, re-measured by ENGINE-3 search
   step 13). The app's 5–30 s per move is more time than that, so "about N" is conservative.
3. **Strong and Club, against Stockfish.**
   - A 40-game probe at `LEVEL` = target, then `GAMES=300` at the `LEVEL` nearest an even score.
   - `UCI_Elo` must be at least 1320, which both targets meet.
4. **Casual and Beginner, against BChess's own measured levels** (Stockfish cannot go below 1320).
   - Casual plays Club (expected 1000 vs 1400, a score of about 9 %). 300 games.
   - Beginner plays Casual.
   - Each link adds its own error (about ±40), so the chain is reported with its summed uncertainty.
5. **Tuning.** A level more than about 100 Elo off its target has its row in `Handicap.hpp` tuned:
   first the temperature, then the depth, then the blindness. The level is then measured again. When
   tuning cannot close the gap, Jean picks between changing the label and accepting it.
6. **Record.** One table in `docs/elo.md` with the five levels, their measured Elo ± error, the
   handicap row and the commit.

## 9. Decisions left open for Jean

**Decision (Jean, 2026-10-07):** go. Implementation starts after ENGINE-3 search lands on `main`.

- D1–D4 as recommended (D1 revised by Jean the same day).
  - The computer is named after its level in the title and the status ("You vs Club Player", "Club
    Player is thinking…").
  - The row reads "Black · Club", or "Black · 10 s" at Maximum.

- **D1 — How a computer is named on the game screen.**
  - Recommended: the title and status use the button's words ("You vs Club Player", "Full Engine is
    thinking…"), and the row detail is "Black · Club" (your example), or "Black · 10 s" at Maximum.
  - Alternative: keep "Computer" as the name ("You vs Computer") and put the level only in the row,
    "Black · Club" or "Black · Maximum 10 s".
- **D2 — The opening book only at Maximum.**
  - Recommended: below Maximum the levels open with their own randomness, so games do not repeat, and a
    600-rated opponent does not play book lines.
  - Alternative: the book at every level with a random choice among its continuations, which needs a
    `ChessOpenings` change.
- **D3 — The natural delay.**
  - Recommended: uniformly 1.0–2.5 s from the start of the search, for every level below Maximum.
  - Alternative: shorter at the low levels (0.5–1.5 s for Beginner and Casual), or a fixed 1.5 s.
- **D4 — Editing players and computer against computer.**
  - Recommended: the same sheet titled "Players" with a "Done" button and no "Random". Computer against
    computer is not offered: old games with two computers still open and play, and editing them makes
    them you against Black's level.
  - Alternative: a seventh row, "Computer vs Computer", at the end of the ladder, Mac only.

## Review round 1 (Codex) — how each finding was handled

Each finding was checked against this worktree and against `engine-3-search` (read-only).

1. **Score sign (blocker). Accepted.** On `engine-3-search`, `MinMaxSearch::alphabeta` (public) ends
   with `return score * color`, and `IterativeDeepening::search` stores it as `evaluation.value`.
   - §2.2 item 3: the child's score is White-relative. It is kept for `value`, and it is multiplied by
     the root's colour for the choice only.
   - New test: `BlackChoosesBlacksBest`.
2. **The Beginner mate test cannot pass (blocker). Accepted.** With the clamp, the window (1000 − 600)
   excluded every non-mate, so the test contradicted the rule. Clamping is dropped (see 4).
   - "Misses mates" is now the depth cap's job: Beginner (depth 1) sees mate in one, not mate in two.
   - Blindness stays about material only. (Round 2 refined this: see the next section, finding 2.)
   - The test became `AFoundMateIsAlwaysPlayed`.
3. **Values shared across regimes (blocker). Accepted.** Confirmed in `TranspositionTable.hpp` on
   `engine-3-search`: `newSearch` only bumps `generation`, and `exists` ignores it. Confirmed in
   `MinMaxSearch.hpp`: the store does not look at `config.transpositionTable`.
   - Each handicapped search now uses a fresh local 1 MB table and never touches
     `IterativeDeepening::table` (§2.2 item 2). This isolates Maximum from the handicapped search, and
     each handicapped move (blind or not) from the next.
   - Rejected alternatives: clearing the shared table, which has no `clear()` and would throw away
     Maximum's ordering; and adding a no-store flag to `MinMaxSearch`, which edits the search.
   - Tests: `DeepEntriesDoNotLiftTheCap` and `BlindValuesDoNotReachMaximum`.
4. **Clamping erases distinctions (should-fix). Accepted.** The choice uses raw scores. Mate scores are
   ±`MAT_VALUE` ∓ plies, far outside any window (at most 4 × 150 = 600 cp), so:
   - a found mate is always played;
   - a forced loss is never chosen while a move that is not mated exists;
   - large advantages keep their order.

   Tests: `AFoundMateIsAlwaysPlayed`, `AForcedLossIsNeverChosen` and `ALargeAdvantageKeepsItsOrder`.
5. **"Scored exactly" overstates (should-fix). Accepted.** The wording now says "the search's value at
   a nominal depth". Selective pruning and extensions apply below each child, which is intended. Step 1
   records which ENGINE-3 options are on in the landed configuration, and calibration measures the
   result.
6. **The delayed-reply test proves nothing (should-fix). Accepted.** The reply goes through a
   `scheduleReply` seam (the `animate` pattern), so the tests capture the block. A captured block is
   the observable proof that the search completed. The I2 test is parameterized over Back, the mode
   change, players, paste, and `cancelSearch` (session replacement). No fixed sleeps.
7. **The UCI gate races `quit` (should-fix). Accepted.** Confirmed: `quit` calls `exit(0)`
   (`UCI.swift`). The gate uses the argument mode with `xcode` (synchronous search), so `bestmove` is
   printed before the exit.
8. **The terminal root (should-fix). Accepted.** §2.2 item 6 covers it:
   - a mated or stalemated root returns an empty line, which gives `hasBestMove == false` and
     `bestmove 0000` (`FENgineInfo+Extension.swift:40`);
   - a root drawn by rule but with legal moves still returns a move.

   Tests: `NoMoveAtCheckmateOrStalemate`, `ARuleDrawnRootStillPlays` and
   `handicappedMateAnswersNullMove`, plus the gate's mated FEN.

## Review round 2 (Codex) — how each finding was handled

1. **Node counting (should-fix). Accepted.** Confirmed on `engine-3-search`: `visitedNodes` is
   incremented only in `alphabeta`'s move loop (`MinMaxSearch.hpp:331`) and quiescence's
   (`:457`). Children at depth 0 with no captures add nothing.
   - `nodes` now counts the root moves searched plus the children's nodes.
   - `selDepth` (the max of `maxPly`) and `movesPerSecond` are filled in.
   - `ResultIsShapedLikeTheSearch` asserts them.
2. **The Beginner horizon claim (should-fix). Accepted.** Confirmed: quiescence searches every evasion
   when in check (ENGINE-3 step 4), so captures with check lead to forced lines past depth 1.
   - §2.2 item 1 now calls the depth a nominal cap. "Misses mates" rests on the shallow cap on quiet
     mating moves and on blindness.
   - New integration test: `QuiescenceFollowsForcingLinesPastTheCap`.
3. **The calibration clock and names (should-fix). Accepted.** Confirmed in `scripts/elo-match.sh`:
   - `pgn_summary` takes the literal `BChess` as the measured side;
   - a time forfeit by either engine invalidates the run.

   §8 item 1 now has:
   - a clock chosen from a timing probe, with an invalid run redone at a longer control;
   - a distinct opponent name in self-play;
   - validator fixtures for both colours and for the both-named-`BChess` case.

   This changes only the later calibration step, not the implementation steps.
