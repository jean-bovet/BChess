# ENGINE-2 — A match-ready UCI engine, and its Elo

Revision 4 (2026-10-06). Codex plan rounds exhausted (3/3); the round-3 changes are covered by the phase-5 code review. Planned on `main` (`--no-worktree`, Jean's call). Implemented **after
ENGINE-1** lands; this plan assumes its fixes (castling rights on rook capture, ep hash, quiescence
return, bishop-pair sign, PGN round-trip, `setFEN` reset) and does not repeat them.

- r1 — first draft.
- r2 — Codex plan round 1 (substantive). Changes:
  - The bridge migration now covers `FEngineConcurrencyTests` and keeps its invalidation check.
  - A FEN that fails to parse restores the start position and drops its moves.
  - New step 2: mate scores carry the distance (through the TT too), and statistics are cumulative,
    one line per completed depth. This pulls "mate distance" out of ENGINE-1's follow-up list.
  - Invalid `go` values are specified and tested.
  - Malformed `position` input, `ucinewgame`, score sign and promotion in the `pv` get direct tests.
  - The `movetime` lower bound is dropped from its test.
  - UCI moves are matched by their UCI string.
  - The script uses absolute paths and measures one level at a time. The combined estimate is
    dropped, and degenerate results are refused.
- r3 — Codex plan round 2 (substantive). Changes:
  - Every `go` value is clamped to a bounded range *before* any arithmetic or narrowing to C++
    `int`; `depth` is at most 64.
  - `FFEN::setFEN` validates its input and is transactional, so the app's Paste is protected too.
  - TT mate-ply normalization gets a store-at-one-ply / probe-at-another test in both directions.
  - Final statistics include the interrupted depth's work.
  - Cumulative counters are 64-bit, and nps is 0 when no time has elapsed.
- r4 — Codex plan round 3 (substantive; last allowed round). Changes:
  - `setFEN` now **rejects** only input that is unsafe or was already rejected, and **sanitizes**
    everything else earlier versions accepted and could save, so I1 holds for old files. There are
    PGN and JSON fixtures for it.
  - Every caller of the deleted APIs is listed and migrated (C++ tests included).
  - A final `info` line is printed before `bestmove`.
  - The TT test uses White-relative scores.
  - `seldepth` is the maximum ply visited.
  - Jean's ENGINE-1 judge for changed best-move tests is reused.

Jean's request: "I am curious to know the ELO of my engine — play it against a reference engine."

To get a number, `BChessUCI` has to survive a few hundred games under a match runner. Today it
can't: it crashes or plays an illegal move as soon as a game reaches a promotion, and it ignores
the clock. Steps 1–4 make it a correct UCI engine. Step 5 adds the measuring tool, and step 6 runs
it once and records the result.

## Problem, with evidence

**P1 — Moves from the GUI are not checked against the legal moves.** `processCmdMove` asserts that
every token is 4 characters (`BChess/UCI/UCI.swift:78`), so `e7e8q` stops a Debug build. In Release
the assert is gone, the promotion letter is dropped, and the pawn lands on the 8th rank as a pawn.
The move itself is built by `ChessBoard::getMove` (`Shared/Engine/ChessBoard.cpp:364-389`). It looks
only at which piece sits on `from` and whether `to` is occupied, then makes a plain move or capture:
- **Promotion is never set.**
- **En passant is never flagged** (`to` is empty, so it comes out as a plain move), and the captured
  pawn stays on the board (`ChessBoard::move` removes it only when `MOVE_IS_ENPASSANT`,
  `ChessBoard.cpp:288`).
- **Illegal input is played** (any `from`→`to` for a piece of the side to move).

Castling given as a king move (`e1g1`) does work, because `ChessBoard::move` moves the rook
whenever the king goes e1→g1/c1 (`ChessBoard.cpp:244-267`). It still does not carry the castling
flag the generator sets (`createCastling`, `Move.hpp:106`).

The only caller of `getMove` is `ChessGame::move(from, to)` (`ChessGame.cpp:133-138`), reached
through `FEngine move:to:` (`FEngine.h:83`, `FEngine.mm:225-229`). C++ tests also call both
directly:
- `ChessBoard::getMove`: `StateTests.cpp:29-59` (8 calls).
- `ChessGame::move(from, to)`: `PGNTests.cpp:190,213,405`, `ChessEngineTests.cpp:73,79` and
  `ChessGameTests.cpp:143,152`.

The bridge's Swift callers are:
- `UCI.swift:87`;
- the test helpers `GameSessionTests.swift:29`, `MoveRowsTests.swift:20` and
  `UCIProcessTests.swift:88`;
- `FEngineConcurrencyTests.swift:50` (the legality check in a concurrency test) and `:154`
  (`expectInvalidates("move:to:")`);
- `GameStateCodingTests.swift:62`.

`isLegalMove` and the check at `:50` therefore accept some illegal moves, so neither can catch an
illegal `bestmove`.

**P2 — The engine's own promotions are written without the piece.** `FPGN::to_string` returns
`from+to` for `SANType::uci` before it looks at the promotion (`Shared/Engine/Helpers/FPGN.cpp:152-154`).
So `bestmove` and the `pv` (`FEngineInfo.mm:86-101`) say `e7e8` where UCI requires `e7e8q`. A match
runner rejects that as illegal, and BChess loses the game.

**P3 — Every mate scores the same, so the engine can't tell a short mate from a long one.**
`ChessEvaluater::evaluate` returns ±`MAT_VALUE` for any mate (`ChessEvaluater.cpp:146-150`).
`MinMaxSearch` passes it up unchanged from three places: the horizon leaf (`MinMaxSearch.hpp:155-163`),
the no-moves node (`:166-169`) and quiescence's stand-pat (`:268`). This has two effects:
- **The search doesn't prefer the shorter mate.** A mating side can drift, and repetition detection
  can turn a won game into a draw. That costs Elo in exactly the endgames a match will reach.
- **`score mate N` has no true N to report.** PV length isn't the distance, because nothing makes
  the defender pick the longest defence.

`FEngineInfo.mat` tests for exact equality with ±`MAT_VALUE` (`FEngineInfo.mm:49`), and the app's
`Verdict` uses it (`EngineView.swift:62`).

**P4 — The search statistics don't add up.** `IterativeDeepening::search`
(`IterativeDeepening.hpp:67-140`) has three problems:
- `nodes` is reset every depth (`minMaxSearch.reset()`, `:88`).
- `time` is whole seconds for the last depth only (`:119`), and `nps` covers that depth only (`:99-100`).
- The callback also runs after an *interrupted* depth, repeating the previous evaluation (`:126-128`, the call at `:127`).

UCI's `nodes`, `time` (ms) and `nps` are cumulative since `go`. The app shows `nodeEvaluated` and
`movesPerSecond` (`EngineView.swift:68-69`) and never reads `time`.

**P5 — `go` ignores the clock.** `processCmdGo` (`UCI.swift:92-113`) looks only at the first
token. Anything other than `infinite` searches for a fixed 10 s (`// TODO time control`, `:104-106`).
That ignores `wtime/btime/winc/binc/movestogo/movetime/depth`, and a 10+0.1 game is lost on time
on move 1. A bare `go` crashes, because `tokens.removeFirst()` runs on an empty array (`:95`).

**P6 — Protocol details a runner trips over.**
- The first stdin line, whatever it is, triggers `id`/`uciok` (`UCI.swift:176-181`). A later `uci`
  falls to `default` (`:142-143`).
- An empty line crashes (`process` → `tokens.removeFirst()`, `:116`), and so does a bare `position`
  (`:58`).
- Unknown commands, including `setoption`, which every runner sends, print `Unknown command …` to
  **stdout** (`:143`).
- `position fen` takes exactly six fields (`:63-65`). Fewer fields crash.
- `FFEN::setFEN` (`Shared/Engine/Helpers/FFEN.cpp:146-218`) validates almost nothing, and fails
  halfway:
  - A rank with more than 8 files, or more than 8 ranks, writes outside the board through
    `board.set` (`:169-187`).
  - An ep field that isn't a square gives `squareForName == SquareUndefined` (255), and
    `bb_set` shifts by 255 (`:203`, `Coordinate.hpp:47-54`). That is undefined behaviour, e.g.
    `position fen 4k3/8/8/8/8/8/8/4K3 w - z9 0 1`.
  - Any side-to-move token other than `w` means Black (`:190`).
  - On an unknown piece letter it returns `false` *after* clearing the board and filling part of
    it (`:166`, `:178-179`), and the moves are then played on that board.

  The same parser serves the app's Paste and PGN `[FEN]` tags. ENGINE-1 step 7 resets the board at
  the start and sanitizes castling rights. It does not validate any of the above.
- `ucinewgame` does nothing (`:129-131`).
- `info` gives `depth` as `max(depth, quiescenceDepth)` (`FENgineInfo+Extension.swift:28`).

**What already works and is reused.**
- `FEngine evaluate:time:callback:` (`FEngine.mm:321-378`) arms its timer *when the search starts*
  (`:353-361`) and calls `stop`, so `time > 0` is the per-move budget.
- `stop` always lets depth 1 finish (`IterativeDeepening.hpp:154-159`), so the result is always a real
  move. `go` with no legal move answers `bestmove 0000` (`FENgineInfo+Extension.swift:33-40`).
- stdin is read on the main thread while callbacks print from the search queue (I4). The subprocess
  harness `UCIProcess` (`BChessTests/UCIProcessTests.swift`) already drives the real binary.
- `UCI.swift` is compiled into `BChessTests` (`project.yml:121-122`). `GamesTests.swift:103-110`
  already drives `UCI().process(&tokens)` in-process and reads `uci.engine.fen()`, so parsing can be
  tested without a subprocess.
- The opening book is never loaded in the tool. `useOpeningBook = true` (`UCI.swift:31`) finds
  nothing, because only `GameSession` calls `loadOpening` (`Shared/Model/GameSession.swift:131`).
  There is no own book to switch off.
- The transposition table is off by default (`FEngine.mm:64`), and the tool never turns it on. The
  app turns it on through the `useTranspositionTable` default (`GameSession.swift:478`).

## Design

### Step 1 — Legal moves from UCI text, and promotions written back (engine + bridge)

- **`FPGN::to_string(…, SANType::uci)`** appends the lowercase promotion letter
  (`FPGN.cpp:152-154`). `bestmove` and `pv` then carry `e7e8q`, and the helper in
  `ChessGameTests.cpp:41` matches promotions too.
- **`Move FPGN::uciMove(ChessBoard board, std::string uci)`** sits next to `getMatchingMoves`
  (`FPGN.cpp:224`). It walks `ChessMoveGenerator::generateMoves(board)` and returns the one
  candidate whose `FPGN::to_string(candidate, SANType::uci)` equals the token, or `INVALID_MOVE`.
  - Exact string equality checks the squares, the promotion letter, castling and en passant at
    once, with no second parser.
  - Malformed tokens, illegal moves and a pawn reaching the last rank without a letter all give
    `INVALID_MOVE`.
  - It has two callers: `ChessGame::move` below, and `StateTests.cpp`, which works on a bare
    `ChessBoard`.
- **`bool ChessGame::move(std::string uciMove)`** replaces `ChessGame::move(from, to)`
  (`ChessGame.cpp:133-138`). It plays `uciMove(board, token)` with the existing
  `move(m, "", false)`, or returns `false` and changes nothing. `ChessEngine::move(from, to)`
  (`ChessEngine.hpp:118`) becomes `bool move(std::string uciMove)` and keeps forwarding, as it does
  today.
- **`ChessBoard::getMove`** (`ChessBoard.cpp:364-389`, `ChessBoard.hpp:67`) is **deleted**.
- **Every caller migrates in the same commit** (the full list is in P1):
  - `StateTests.cpp`: `board.move(board.getMove("e2", "e4"))` becomes
    `board.move(FPGN::uciMove(board, "e2e4"))`, with `ASSERT_TRUE(MOVE_ISVALID(…))` through a
    one-line local lambda.
  - `PGNTests.cpp`, `ChessEngineTests.cpp` and `ChessGameTests.cpp`: `game.move("c1", "d1")` becomes
    `ASSERT_TRUE(game.move("c1d1"))`. A test that silently relied on an illegal or flagless move
    fails and is fixed there. Expected strings stay the same; the generator's move now also carries
    the check flag.
  - The Swift callers are covered in the next bullet.

  A grep for `getMove(`, `.move("` with two square arguments, and `move(_:to:)` must come back
  empty before the step is done.
- **Bridge:** `- (BOOL)moveUCI:(NSString*)move NS_SWIFT_NAME(move(uci:))` replaces `move:to:`
  (`FEngine.h:83`, `FEngine.mm:225-229`) and keeps the `[self invalidate]` first.
  - All seven Swift call sites move to it, including `GameStateCodingTests.swift:62`
    (`move(uci: "a7a6")`).
  - `FEngineConcurrencyTests.swift:154` becomes `expectInvalidates("move(uci:)") { $0.move(uci: "a2a3") }`,
    so the invalidation regression stays covered.
  - `:50` and `isLegalMove` use the returned `Bool`: legal means `true`. That is a real legality
    check, where comparing FENs was not.
- **`FFEN::setFEN` is safe and all-or-nothing, without rejecting anything earlier versions could
  save.** It builds on ENGINE-1 step 7 (`board.reset(); board.clear();` at the start), which now runs
  on a local `ChessBoard parsed`. `parsed` is assigned to `board` only on success, so on `false` the
  caller's board is untouched.

  This matters because earlier versions saved the *original* FEN text: `ChessGame::setFEN` keeps it
  in `initialFEN` (`ChessGame.cpp:36`), and `FPGN::getGame` writes it to `[FEN]` (`FPGN.cpp:981-984`).
  It is inside the `pgn` of a `GameState` JSON too (`GameState.swift:32`). So whatever the old
  parser accepted may be in a user's file. The rules apply to every caller (files, Paste, UCI):
  - **Rejected** (return `false`) — only what is unsafe or already rejected:
    - a rank with more than 8 files, or more than 8 ranks (today these write outside the board or
      shift by a negative or ≥ 64 amount, `FFEN.cpp:169-187`);
    - an unknown piece letter (already rejected today, `:178-179`; now without a half-built board);
    - fewer than two fields (already rejected, `:156`).
  - **Sanitized** (accepted, with the value made safe):
    - an ep field that isn't a square on rank 3 or 6, unknown names like `z9` included, becomes `-`
      (today `z9` is a shift by 255);
    - castling letters other than `KQkq` are dropped. ENGINE-1 step 7 already drops rights whose
      king or rook is not at home.
  - **Unchanged**, because earlier versions accepted them and they are safe:
    - short ranks and fewer than 8 ranks (the missing squares are empty);
    - a side-to-move token other than `w`, which means Black (`:190`);
    - lenient half-move and full-move numbers (`integer()` gives 0 on text), which keeps EPD
      (`… w - - bm Nf6+;`) working.

  Here r4 deliberately keeps short placements and odd side tokens, which the lead's guidance listed
  as reject. Both are safe, and both may be in saved files, so rejecting them would break I1.
  `initialFEN` keeps the original text, as today. The sanitizing is the same on every read, so a
  replay (`ChessGame.cpp:199,226`) and a re-save are stable. This does **not** rely on ENGINE-1's
  narrowed I1 exception, which covers only illegal games the castling bug let through. King count
  and legality of the position are out of scope.

### Step 2 — Mate distance and consistent statistics (engine)

- **Mate scores carry the ply.** A helper in `MinMaxSearch`,
  `static int mateAtPly(int score, int ply)`, turns ±`MAT_VALUE` into ±(`MAT_VALUE − ply`) and
  leaves any other score alone. It is applied at the three places a node's own evaluation is
  returned: the horizon leaf, the no-moves node and the quiescence stand-pat (`MinMaxSearch.hpp:155-169`,
  `:268`). `depth` is already the ply from the root there. A shorter mate now scores higher for
  the winner, and a longer one for the loser.
  - `ChessEvaluater::evaluate` keeps returning ±`MAT_VALUE` (`EvaluationTests` unchanged).
  - New `ChessEvaluater::isMateScore(v)` (`|v| > MAT_VALUE − MAX_MATE_PLY`, with
    `MAX_MATE_PLY = 1000`) and `matePlies(v)` (`MAT_VALUE − |v|`).
- **TT:** the table is optional but reachable from the app, so mate scores are stored relative to
  the node and read back relative to the root. The standard adjustment is: on `store`, a mate score
  moves `ply` further from zero; on probe, `ply` back (`MinMaxSearch.hpp:114-148` probe, `:243-248`
  store). Without this, a mate found through a transposition would report the wrong distance.
  - Two static helpers do it: `ttValueToStore(v, ply)` and `ttValueFromProbe(v, ply)`.
  - The probe converts *before* the EXACT/ALPHA/BETA comparisons with `alpha`/`beta` and before
    `pv.push`, so bound checks see root-relative values.
- **Bridge:** `FEngineInfo.mat` becomes `ChessEvaluater::isMateScore(value)` (`FEngineInfo.mm:49`),
  so the app's `Verdict` keeps working. A new read-only `matePlies` (0 when not a mate) gives UCI
  its distance: `mate N` with `N = (matePlies + 1) / 2`, signed from the engine's side.
- **Statistics** (`IterativeDeepening::search`):
  - One clock starts when `search()` starts. `ChessEvaluation.nodes` adds up over all depths.
  - `ChessEvaluation.time` becomes **milliseconds since the search started** (only UCI reads it).
  - `movesPerSecond` is `nodes * 1000 / time`, and **0 when `time` is 0**.
  - **Widths:** `ChessEvaluation.nodes`, `time` and `movesPerSecond`, and `MinMaxSearch.visitedNodes`
    become `int64_t` (`ChessEvaluation.hpp:21-23`; `int` today). `FEngineInfo` already exposes
    `NSInteger`, which is 64-bit on every supported platform.
  - The per-depth callback fires **only after a completed depth** (inside the
    `curMaxDepth == 1 || running()` branch).
  - **The returned evaluation** (the final `done` callback from `searchBestMove`) keeps the score,
    PV and depth of the last *completed* depth. After the loop, its `nodes`, `time` and `nps` are
    refreshed to include all work up to termination, including an interrupted depth. The last
    `info` before `bestmove` therefore accounts for all the time spent.

  The elapsed time lives in each search's own evaluation, so UCI keeps no mutable timestamp that
  the search thread would read.
- **`seldepth` is the deepest ply visited.** `MinMaxSearch` keeps `int64_t maxPly`, reset when the
  search is armed, and raised to `depth` on entry to every `alphabeta` and `quiescence` node.
  `MinMaxVariation::push` overwrites `qsDepth` with the chosen line's own depth
  (`MinMaxSearch.hpp:46-50`), so `qsDepth` can't measure exploration off the PV. A new
  `ChessEvaluation.selDepth` and `FEngineInfo.selDepth` carry the maximum. `quiescenceDepth` keeps
  its meaning for the app's readout (`EngineView.swift:71-72`).
- **Best-move tests that change** because the engine now prefers the shorter mate use Jean's
  ENGINE-1 judge (decided 2026-10-06): Stockfish from Homebrew. A new line is accepted when its
  first move is within 30 cp of Stockfish's best at depth 20 and no worse than the old one. Mate
  positions are judged by Stockfish's `mate N`, so the new move must mate at least as fast.

### Step 3 — UCI protocol hygiene (`BChess/UCI/UCI.swift`, `FENgineInfo+Extension.swift`)

- `uci` becomes a command in `process`: it prints `id name BChess`, `id author Jean Bovet` and
  `uciok`. `run()` stops treating the first line specially, so every line goes through `process`.
  No `option` lines are advertised (Decision 5).
- Blank lines are ignored. `setoption`, `debug`, `register`, `ponderhit` and unknown commands are
  ignored on stdout and logged with `os_log`, as the UCI spec asks. After this, the only lines
  BChess prints are `id`, `uciok`, `readyok`, `info` and `bestmove`.
- `position` is all-or-nothing:
  - Bare `position`, or an unknown sub-command: ignored and logged; the position is unchanged.
  - `startpos`: `setFEN(StartPosFEN)`.
  - `fen`: the FEN is every token up to `moves` or the end of the line, so 4- and 6-field FENs both
    work. An empty FEN, or one the validating `setFEN` (step 1) rejects, means
    `setFEN(StartPosFEN)` again: the start position, the moves **ignored**, logged.
  - `moves`: played in order through `engine.move(uci:)`. At the first `false`, the moves before it
    stay, the rest are dropped, and it is logged. No assert, no crash.
- `ucinewgame` calls `engine.setFEN(StartPosFEN)`.
- `info`, one line per completed depth (step 2):
  `info depth D seldepth S score cp X|mate N time T nodes K nps P pv …`.
  - `depth` is `info.depth`, and `seldepth` is `info.selDepth`, the maximum ply visited (step 2).
  - **On the `completed` callback, `processCmdGo` prints one final `info` line, then `bestmove`.**
    That line carries the refreshed totals (step 2: `nodes`/`time`/`nps` through termination, with
    the score and PV of the last completed depth). It is skipped when there is no best move; then
    only `bestmove 0000` is printed.
  - `time`, `nodes` and `nps` come straight from the step 2 values.
  - `score` is from the engine's point of view, as now (`FENgineInfo+Extension.swift:18-26`).
  - `uciInfoMessage` is also compiled into the apps (`project.yml:47,78`), but they never call it.
    `GamesTests.swift:120` uses only `uciBestMove`, which is unchanged.
- Dead code goes: `performance()` (`UCI.swift:147-153`), the commented blocks (`main.swift:11-12,15`,
  `UCI.swift:157-165`) and `write` (folded into `engineOutput`). The `xcode` command and the
  command-line mode stay. Neither prints extra lines, and no match runner uses them.

### Step 4 — Time management (`go`)

A pure value type in `UCI.swift`, testable without a process:

```swift
nonisolated struct SearchLimits: Equatable, Sendable {
    var wtime, btime, winc, binc, movestogo, movetime, depth: Int?   // ms / count / plies
    var infinite = false
    init(goTokens: [String])
    /// What FEngine.evaluate(_:time:) takes: depth -1 = unlimited, time 0 = no timer.
    func search(whiteToMove: Bool) -> (depth: Int, time: TimeInterval)
}
```

**Parsing.** `go` takes key/value pairs.
- A key with a missing or non-integer value (including one that overflows `Int`) is treated as
  absent. Unknown keys and their arguments (`nodes`, `searchmoves …`, `ponder`, `mate`) are skipped.
- **Every value is clamped at parse time**, before any arithmetic or narrowing:
  - `wtime/btime/winc/binc/movetime` to `[0, maximum]`, with `maximum = 86_400_000` ms (one day);
  - `movestogo` < 1 is absent, and above 1000 becomes 1000;
  - `depth` to `[1, 64]`. 1 so a legal move is always found; 64 so the `(int)depth` narrowing in
    `FEngine.mm:363` can never wrap. Today `depth 4294967296` would become 0, search nothing and
    answer `bestmove 0000`.

  After clamping, `remaining / movestogo + inc` is at most about 1.7 × 10⁸, so no intermediate can
  overflow. Saturating arithmetic isn't needed.

**Allocation**, all in ms, with `overhead = 50`, `minimum = 10` and the same `maximum`. The maximum
also keeps `time * NSEC_PER_SEC` from overflowing (`FEngine.mm:355`):
- `infinite`, or no clock for the side to move and no `movetime`: no timer. `depth` is used if
  given, else unlimited, and the search answers on `stop`, as now.
- `movetime m`: `clamp(m − overhead)`.
- Clock (`wtime`/`btime` for the side to move): `budget = remaining / (movestogo ?? 30) + inc`, then
  `min(budget, remaining − overhead)`, then clamped to `[minimum, maximum]`. At 10+0.1 that is
  ≈ 433 ms on move 1, and it shrinks as the clock runs down.
- `depth d` (already in `[1, 64]`) also caps the depth when there is a clock or a `movetime`.

`processCmdGo` parses the limits and calls `engine.evaluate(depth, time:)`. The `stop`/`bestmove`
path is unchanged.

**Hard limit only.** When the budget runs out, the depth in progress is aborted and the last
completed depth is returned. There is no rule to stop starting new depths (see Alternatives).

### Step 5 — Elo tooling (no app code)

**`scripts/elo-match.sh`** (bash, `set -euo pipefail`). It runs from anywhere:
`ROOT=$(git -C "$(dirname "$0")" rev-parse --show-toplevel)`, and every path is absolute under
`$ROOT/.elo/`, which is added to `.gitignore`. Nothing binary is committed.

1. **Tools.** `stockfish` comes from `brew install stockfish` (19 today). For `fastchess`, the
   script uses `$ROOT/.elo/fastchess/fastchess` if it is not on `PATH`. When that is missing too, it
   clones the **pinned release tag** of `github.com/Disservin/fastchess` and runs `make -j`. The tag
   is recorded in the script. There is no Homebrew formula (`brew info fastchess`: none).
2. **Book.** It fetches `8moves_v3.pgn` from `official-stockfish/books` once, from a pinned commit
   URL, into `$ROOT/.elo/books/`. A sha256 written in the script must match, or the script stops.
3. **Build.** `xcodebuild -project "$ROOT/BChess.xcodeproj" -scheme BChessUCI -configuration Release -derivedDataPath "$ROOT/.elo/dd" build`.
4. **One level per run.** The inputs are `LEVEL` (Stockfish `UCI_Elo`; 1320 is the lowest it
   accepts), `GAMES` (even), `TC` (default `10+0.1`) and `CONCURRENCY` (default 4: the M2 has 4
   performance cores, and the efficiency cores add noise). The run is equivalent to:
   ```
   fastchess -engine cmd="$BCHESS" name=BChess \
             -engine cmd=stockfish name=SF$LEVEL option.UCI_LimitStrength=true option.UCI_Elo=$LEVEL option.Threads=1 option.Hash=16 \
             -each tc=$TC timemargin=100 -openings file="$BOOK" format=pgn order=random \
             -repeat -games 2 -rounds $((GAMES/2)) -concurrency $CONCURRENCY -recover \
             -draw movenumber=40 movecount=8 score=10 -resign movecount=4 score=1000 twosided=true \
             -pgnout file="$ROOT/.elo/runs/$STAMP-SF$LEVEL.pgn"
   ```
   The flag spellings are checked against the pinned version's `--help`. `-repeat` plays each
   opening with both colours.
5. **Report.**
   - W/D/L, score %, and fastchess's Elo difference ± 95%.
   - BChess losses by illegal move, time forfeit or disconnect, counted from the PGN `Termination`.
   - The performance `LEVEL + diff ± err`, and a ready-to-paste Markdown row for `docs/elo.md`.
6. **Results that are not a number.**
   - **Invalid**: any illegal move or disconnect. That is a bug to fix, not a rating.
   - **Out of range**: a score outside 10–90%, an all-win or all-loss run, or no finite interval
     from fastchess. The script prints "out of range — try `LEVEL=<L±300, at least 1320>`" and
     records no rating.
   - There is no combined multi-level estimate. One informative level, with its interval, is the
     result.

**`docs/elo.md`** covers:
- Method and setup (three commands), how to run, and how long it takes.
- **Caveats:**
  - Stockfish's `UCI_Elo` is calibrated against CCRL 40/4 at a longer time control (60+0.6 in its
    documentation; confirm against the installed version), so 10+0.1 numbers are indicative.
  - The rating is relative to that anchor, not FIDE.
  - Engine weaknesses the number will reflect: no TT in the tool, no fifty-move rule, no
    quiescence in check.
- The error-bar table below.
- A **Results** table: date, commit, TC, book, level, games, W/D/L, performance ± 95%, wall time.

**Error bars** (95%, near a 50% score, about 20% draws; the per-game score variance is about 0.2,
and 1 score point ≈ 695 Elo at 50%):

| Games | ± Elo |
|------:|------:|
| 100 | ±61 |
| 200 | ±43 |
| 300 | ±35 |
| 400 | ±31 |
| 1000 | ±19 |

They widen as the score moves away from 50%, which is why the level is chosen near the engine.

**Time on this Mac (M2, concurrency 4)**: a 10+0.1 game is ≤ 2 × (10 + 0.1 × moves) s, about 25 s of
wall time with adjudication. 300 games × 25 s / 4 ≈ **30 min**. At 60+0.6 the same run takes ≈ 3 h.

### Step 6 — First measurement (default: run it)

1. Probe: `LEVEL=1600 GAMES=40` (≈ 4 min). Its performance (or the out-of-range hint) picks the
   level: the performance rounded to 100, at least 1320.
2. Measure: `GAMES=300` at that level (≈ 30 min, ±35). Record it in `docs/elo.md` → Results with the
   interval, wall time and commit, and put a one-line summary in the README row.
3. If the score is still out of range, move the level once more. Below 10% at 1320 means the
   fallback in Decision 2.

An invalid run is a bug to fix in steps 1–4, not a number to record.

### Reuse

- `ChessMoveGenerator::generateMoves` and `FPGN::to_string(…, uci)` to match moves;
  `ChessGame::move(Move, …)` to play them.
- `FEngine evaluate:time:callback:`, `stop` and its generation guard.
- `FEngineInfo` `mat`/`depth`/`quiescenceDepth`/`bestLine(true)`/`uciBestMove`.
- The in-process `UCI().process` pattern (`GamesTests.swift:103-110`) for parsing tests, and the
  `UCIProcess` harness for stdout and timing.
- `os_log` for diagnostics.
- No new files in the app targets, and no `project.yml` change. The new test file sits in the
  `BChessTests` folder source.

## Alternatives rejected

- **Parse UCI moves in Swift against `engine.allMoves()`.** That fixes the tool but leaves
  `ChessBoard::getMove` building illegal or flagless moves for anything else. Fixing it in the engine
  is the same amount of code, and it is testable as plain C++ (I3).
- **Parse squares and promotion separately (r1).** It is a second parser; comparing UCI strings is
  exact and shorter (Codex r1).
- **Keep `move:to:` and add `moveUCI:` beside it.** That is two ways to play a move from text, one
  of them wrong for promotion and en passant.
- **Mate distance from the PV length (r1).** It is wrong: the PV need not hold the longest defence
  (Codex r1).
- **Report mates without a distance** (Codex's fallback). Rejected because it leaves the strength
  bug: without a distance, the engine still doesn't prefer the faster mate. The fix is about a dozen
  lines in one function, plus the TT adjustment.
- **Strict FEN validation, rejecting short ranks, odd side tokens and bad ep/castling (r3).** It would stop files earlier versions saved from opening (Codex r3; I1). Unsafe input is rejected; the rest is sanitized.
- **Validate the FEN only at the UCI boundary** (Codex r2's suggestion). It would leave the app's Paste and PGN `[FEN]` path with the same undefined behaviour. One check in the parser covers every caller, and it is plain C++ that GoogleTests can exercise.
- **Saturating arithmetic for `go`** (Codex r2). Clamping every input to a bounded range at parse time makes overflow impossible with ordinary arithmetic, and it is easier to read and test.
- **A UCI-side `go` timestamp (r1).** It is mutable state read from the search thread; the
  evaluation's own elapsed time does the job (Codex r1).
- **Soft time limit** (don't start a depth past half the budget). It saves clock but changes no move.
  It is a strength tweak for later.
- **Node limits (`go nodes`).** The search has no node check. The token is skipped, and clocks are
  the runners' default.
- **cutechess-cli** as the runner. It is not in Homebrew and needs Qt to build. fastchess builds with
  `make` and reports Elo±, illegal moves and timeouts. (Decision 1.)
- **The repo's `BChess/Openings.pgn` as the match book.** It holds variations and uneven lines.
  `8moves_v3` is balanced, standard, and pinned by hash.
- **UHO books.** They are built to be unbalanced, to separate strong engines. At this level they
  mostly add noise.
- **Several levels and an inverse-variance estimate (r1).** The weighting is undefined at 0%/100%
  and assumes the levels are calibrated alike. One informative level is simpler and honest about its
  interval (Codex r1).
- **Exposing `Hash`/`Threads`/`OwnBook`.** There is no book, the search is single-threaded, and the
  TT stays off (Decision 5). Nobody would set these options.
- **Running Elo in CI.** It takes tens of minutes and needs network tools. It is a manual measurement.

## Test plan

Each test is written first and seen red on `main` + ENGINE-1.

| Step | Test | Proves | Red today |
|------|------|--------|-----------|
| 1 | `MoveTests.UCIStringHasPromotion` (GoogleTest): `to_string(createPromotion(b7,b8,WHITE,PAWN,QUEEN), uci) == "b7b8q"`; knight → `"b7b8n"` | P2 | yes |
| 1 | `FEngineTests.moveUCIPlaysSpecialMoves` (Swift): from `8/1P6/8/8/8/8/8/k3K3 w - - 0 1`, `b7b8n` → knight on b8; en passant `e5d6` → the captured pawn is gone; `e1g1` → rook on f1; each returns `true` and the FEN is exact | legal matching of every special move | yes (no `move(uci:)`; ep leaves the pawn) |
| 1 | `FEngineTests.moveUCIRejectsIllegal`: `e2e5`, `b7b8` (no letter), `zz99`, `e2e4q`, `""` → `false`, FEN unchanged | no silent illegal moves | yes |
| 1 | `FEngineConcurrencyTests.positionChangeInvalidatesSearch` with `move(uci:)`, and the migrated C++ callers (`StateTests`, `PGNTests`, `ChessEngineTests`, `ChessGameTests`) asserting each move is legal | invalidation still covered; no test relied on an illegal move | — (migrated) |
| 1 | `FEN.RejectsOnlyUnsafe` (GoogleTest, new `BChessTests/FENTests.cpp`): `setFEN` returns `false` **and the board keeps its prior value** for a 9-file rank `4k4/8/8/8/8/8/8/4K3 w`, 9 ranks, and an `x` piece letter (the last one half-filled the board before) | unsafe input can't write outside the board or leave a half-built one | yes (UB, half-filled board) |
| 1 | `FEN.SanitizesLegacy`: `4k3/8/8/8/8/8/8/4K3 w - z9 0 1` and `… w - e4 0 1` load with ep `-`; `… w KXq - 0 1` loads with only the rights ENGINE-1 keeps; `4k3/8/8/8/8/8/8/4K2 w` (short rank) and `4k3/8/8/8/8/8/8/4K3 x` (odd side token → Black) load as today; the EPD line `1rbq1rk1/p1b1nppp/1p2p3/8/1B1pN3/P2B4/1P3PPP/2RQ1R1K w - - bm Nf6+; id "position 01";` loads; every perft position's `getFEN` round-trips | I1: nothing an earlier version accepted is rejected, and unsafe values are neutralised | yes (`z9` UB) |
| 1 | `GameStateCodingTests.legacyFENFilesOpen` (Swift; inline fixtures holding the exact bytes of a saved file, so no bundle resources are needed): a `.pgn` with `[FEN "4k3/8/8/8/8/8/8/4K3 w KXq e4 0 1"]` and one move, and a `GameState` `.json` whose `pgn` holds the same tag, both open through the app's own reading path (`GameState` decoding + `FEngine.setPGN`), with the expected position after the move | I1 on real saved-file shapes | yes (ep `e4` gives a wrong ep bit today; the fixture asserts the sanitized FEN) |
| 2 | `MinMaxSearch.MateCarriesDistance` (GoogleTest, TT off **and** on): `6k1/5ppp/8/8/8/8/8/R5K1 w - - 0 1` at depth 3 → `MAT_VALUE − 1`; a mate-in-2 FEN (chosen by the implementer and confirmed by `stockfish` reporting `mate 2`) at depth 4 → `MAT_VALUE − 3`, and Black to move in a mirrored mate → `−(MAT_VALUE − 1)` | P3 distance, sign, TT adjustment | yes (`MAT_VALUE`) |
| 2 | `MinMaxSearch.TTMateIsPlyRelative` (GoogleTest, one shared `TranspositionTable`, TT on). **All scores are White-relative, as the public `alphabeta` returns them (`return score * color`, `MinMaxSearch.hpp:96-101`).** P = White to move, mate in 2; Q = Black to move with a single legal move, which leads to P. (a) Search P at depth 4 (expect `+(MAT_VALUE − 3)`), then Q at depth 5 with the same table: P is probed at ply 1, and Q gives `+(MAT_VALUE − 4)`. (b) Fresh table: Q at depth 5 first (P stored at ply 1), then P at depth 4: the root probe gives `+(MAT_VALUE − 3)`. Mirrored (Black mates): the same with the sign flipped, `−(MAT_VALUE − 3)` and `−(MAT_VALUE − 4)`. | (a) fails if the probe adjustment is removed, (b) if the store adjustment is removed; both signs; bound entries compared in root-relative values | yes (no adjustment) |
| 2 | `MinMaxSearch.SelDepthIsDeepestVisited`: a position where a capture sequence off the PV runs deeper in quiescence than the PV line (the implementer picks one, checked by logging `maxPly` vs the PV's `qsDepth`) → `selDepth` > the PV's `qsDepth` | `seldepth` is the maximum ply, not the PV's | yes (no `selDepth`) |
| 2 | `MinMaxSearch.PrefersShorterMate`: a position with a mate in 1 and a longer mate available, depth 4 → the best move is the mate in 1 | P3 strength effect | yes, if the longer mate's move is generated first (the implementer picks such a position) |
| 2 | `IterativeDeepening.StatisticsAreCumulative` (GoogleTest): depth-3 search; the callback fires 3 times, with depths 1, 2, 3; nodes strictly increase; the last `nodes` = sum of the per-depth visits; `time` (ms) does not decrease | P4 | yes (per-depth nodes) |
| 2 | `IterativeDeepening.NoCallbackForInterruptedDepth`: stop during depth 2 through the `MinMaxSearch::checkpoint` test hook (`MinMaxSearch.hpp:72`, `:213`) → no second per-depth callback | P4 | yes |
| 2 | `IterativeDeepening.FinalStatsIncludeInterruptedDepth`: depth-limited search stopped through the checkpoint after N > 0 extra nodes in depth 3 → the returned evaluation has `depth` 2 and the depth-2 PV and score, while `nodes` = last per-depth `nodes` + the extra nodes and `time` ≥ the last per-depth `time` | interrupted work is counted; score and PV still come from a completed depth | yes |
| 2 | `IterativeDeepening.NpsWithZeroTime`: the helper that computes nps returns 0 for `time` 0 and `nodes * 1000 / time` otherwise, with `int64_t` nodes above 2³¹ | no divide by zero, no 32-bit wrap | yes |
| 3 | `UCICommandTests` (in-process, `UCI().process`, `FEngine.fen()`, new file): bare `position` → unchanged; `position fen` with no FEN → start; `position fen 4k3/8/8/8/8/8/8/4K2X w - - 0 1 moves e1e2` → start position, moves ignored; 4-field `position fen 4k3/8/8/8/8/8/8/4K3 w -` → that position; `position startpos moves e2e4 e7e9 d2d4` → after e4 only; `position fen X` then `ucinewgame` → start | P6 all-or-nothing `position`, `ucinewgame` | yes (crashes, partial board, no reset) |
| 3 | `UCIProcessTests.promotionInPositionMoves`: `position fen 8/1P6/8/8/8/8/8/k3K3 w - - 0 1 moves b7b8q`, `go depth 1` → `bestmove` legal (`move(uci:)` returns `true`) in `1Q6/8/8/8/8/8/8/k3K3 b - - 0 1` | P1 end to end, no crash | yes (assert) |
| 3 | `UCIProcessTests.unsafeAndLegacyFENs`: (a) `position fen 4k4/8/8/8/8/8/8/4K3 w - - 0 1 moves e1e2` (9-file rank) → `isready` gives `readyok` (process alive), and `go depth 1` gives a `bestmove` legal from the **start** position. (b) `position fen 4k3/8/8/8/8/8/8/4K3 w - z9 0 1 moves e1e2` → sanitized, not rejected: `go depth 1` gives a `bestmove` legal for Black in `4k3/8/8/8/8/8/4K3/8 b - - 1 1` | unsafe input falls back to the start position; legacy input is sanitized, end to end | yes (UB / a move from a bad board) |
| 3 | `UCIProcessTests.finalInfoBeforeBestMove`: middlegame, `go movetime 300` → the line just before `bestmove` is an `info` whose `nodes` are greater than the previous `info`'s, and whose `time` is not smaller | the final totals reach stdout and include the interrupted depth | yes (no final line) |
| 3 | `UCIProcessTests.promotionInBestMoveAndPV`: same start, `go depth 3` → some `info … pv b7b8q …` and `bestmove b7b8q` | P2 end to end | yes (`b7b8`) |
| 3 | `UCIProcessTests.onlyUCILinesOnStdout`: `uci`, a blank line, `setoption name Hash value 16`, `foo`, bare `position`, `isready`, `position fen <middlegame>`, `ucinewgame`, `go depth 2` (no `position` after `ucinewgame`) → every line matches `^(id |uciok$|readyok$|info |bestmove )`; the `bestmove` is legal from the **start** position | stdout clean, and the reset is seen end to end | yes |
| 3 | `UCIProcessTests.scoreIsFromTheEngineSide`: White to move, White a queen up → `score cp` > 0; the same position mirrored with Black to move → `score cp` > 0; Black to move with a mate in 1 → `score mate 1` | sign on both sides, `mate N` | yes (`mate`) |
| 3 | `UCIProcessTests.mateIsReportedAsMate`: `6k1/5ppp/8/8/8/8/8/R5K1 w - - 0 1` `go depth 3` → `info … score mate 1 …`, `bestmove a1a8` | `score mate` | yes |
| 4 | `SearchLimitsTests` (pure Swift Testing, new file): parse of `wtime 10000 btime 9000 winc 100 binc 100`, `movetime 500`, `depth 4`, `infinite`, bare, unknown keys (`nodes 5 searchmoves e2e4 d2d4 depth 3` → depth 3); invalid values: `movestogo 0`, `depth 0` → 1, `wtime -5`, `wtime abc`, `wtime 99999999999999999999` (overflow), `wtime` with no value, **`wtime 9223372036854775807 winc 9223372036854775807` → clamped, no trap, budget = one day − 50 ms**, **`depth 4294967296` → 64**, `movestogo 5000` → 1000. Allocation: 10+0.1 White → 433 ms; Black uses `btime`; `movestogo 1` with 1000 ms → 950; 30 ms left → 10; movetime 500 → 450; depth only → (4, 0); a huge clock → the one-day cap | the formula and every edge, with no divide by zero | yes (type missing) |
| 4 | `UCIProcessTests.clockIsHonoured`: `go wtime 3000 btime 3000` → `bestmove` within 1.0 s, legal | P5 | yes (10 s) |
| 4 | `UCIProcessTests.movetimeIsHonoured`: `go movetime 300` from a middlegame → `bestmove` within 1.5 s, legal (no lower bound: a search may legitimately finish early) | `movetime` | yes (10 s) |
| 4 | `UCIProcessTests.depthEndsTheSearch`: `go depth 2`, no `stop` → `bestmove` within 5 s, and the last `info` has `depth 2` | depth honoured | yes |
| 4 | the existing `goInfiniteThenStopPrintsBestMove` and `positionWithoutMovesPrintsTheNullMove` | `infinite`/`stop`/`0000` unchanged | — |

Every step that adds GoogleTests raises the `EngineGoogleTests.registersAllCases` floor (`EngineGoogleTests.swift:30`) to the new total, as ENGINE-1 does.

The process tests run in Debug, each in under a second, so the added suite stays well under 10 s.
Step 5 has no unit test. Its check is a smoke run (`LEVEL=1320 GAMES=4 TC=2+0.05`) that must finish
with no invalid game, reported in the step's commit message.

## Invariants

- **I1 — Files keep opening.** Holds.
  - PGN writing uses the SAN types, and only `SANType::uci` gains the letter.
  - No stored format holds UCI text (`FEngineMoveNode.mm:27` uses `tight`).
  - Scores are never stored.
  - `FFEN::setFEN` rejects only input that is unsafe (writes outside the board) or was already
    rejected. Everything else earlier versions accepted keeps loading, with an impossible ep square
    or unknown castling letters sanitized. Earlier saves can hold the *original* pasted FEN text
    (`initialFEN` → `[FEN]`), so this is checked with saved-file fixtures (`legacyFENFilesOpen`).
    It does not rely on ENGINE-1's narrowed I1 exception.
- **I2 — Search results land on their position.** Holds. `move(uci:)` keeps `[self invalidate]`, and
  the migrated `expectInvalidates` proves it. The other step 2 changes (mate scores, statistics, one
  callback per completed depth) change what a callback says, not when or whether it can land.
  `FEngine.mm`'s generation guard is untouched.
- **I3 — Portable engine.** Holds. Steps 1–2 are plain C++ in `ChessEngine.hpp`, `FPGN.cpp`, `FFEN.cpp`,
  `MinMaxSearch.hpp`, `IterativeDeepening.hpp` and `ChessEvaluater`. Code is deleted from
  `ChessBoard.cpp` and `ChessGame.cpp`.
- **I4 — The UCI tool keeps working.** This is the invariant most at risk, and it is held:
  - stdin stays on the main thread, and callbacks print from the search queue.
  - UCI keeps no state the search thread reads (time comes from the evaluation).
  - `stop` and the timers go through the existing generation guard.
  - Every new input path ends in "ignore and log", never an assert or an empty `removeFirst`.
  - The existing stop/0000 tests stay. The new tests cover promotion, malformed `position`,
    `ucinewgame`, clocks, `movetime`, `depth`, score signs and stdout.
- **I5 — Private and offline.** Holds for the apps. The Elo script downloads developer tools
  (fastchess source, the book) into the git-ignored `.elo/`, only when run by hand. Nothing reaches
  the app or CI.

## Risks and rollout

- **The app's analysis changes a little**: shorter mates win, and the readout is cumulative.
  `Verdict` still says "forced mate" through `mat`. `nodeEvaluated` now counts the whole search,
  which is what a reader expects.
- **Stockfish's calibration** at 10+0.1 is approximate. The number is reported with the TC, and
  Decision 3 offers the calibrated TC.
- **The engine may sit below 1320**, Stockfish's lowest level. Decision 2 has the fallback.
- **Root repetition.** In a position that already occurred three times, the search returns no move
  (`MinMaxSearch.hpp:152`), and BChess would answer `0000`. fastchess ends the game at threefold
  before asking, so this only matters if the two disagree on repetition. The report counts illegal
  moves and disconnects, so a disagreement would show.
- **C++ `assert`s stay on in Release** (no `NDEBUG` in `project.yml`). That is slower, but correct.
  Turning them off is an app-wide build change, out of scope.
- **Machine load** makes time forfeits more likely. `timemargin=100` and a concurrency of 4 keep
  them rare, and the report counts them.
- No device needed. The gates in `/develop` cover the code, and step 6 runs on Jean's Mac.

## Decisions (Jean's go, 2026-10-06 — all defaults)

1. **Match runner:** fastchess.
2. **Reference opponent:** Stockfish 19 with `UCI_LimitStrength`. A CCRL-rated small engine is used
   only as the fallback if BChess scores below 10% at 1320.
3. **Time control:** 10+0.1.
4. **First run:** a probe, then 300 games at one level, recorded as step 6.
5. **Transposition table in the tool:** off.
