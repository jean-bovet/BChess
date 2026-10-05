# ENGINE-2 — A match-ready UCI engine, and its Elo

Revision 1 (2026-10-06). Planned on `main` (`--no-worktree`, Jean's call). Implemented **after
ENGINE-1** lands; this plan assumes its fixes (castling rights on rook capture, ep hash, quiescence
return, bishop-pair sign, PGN round-trip, `setFEN` reset) and does not repeat them.

Jean's request: "I am curious to know the ELO of my engine — play it against a reference engine."

To get a number, `BChessUCI` has to survive a few hundred games under a match runner. Today it
can't: it crashes or plays an illegal move as soon as a game reaches a promotion. It also ignores the
clock. Steps 1–3 make it a correct UCI engine. Step 4 adds the measuring tool, and step 5 runs it
once and records the result.

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
flag the generator sets (`createCastling`, `Move.hpp:106`). The only caller of `getMove` is
`ChessGame::move(from, to)` (`ChessGame.cpp:133-138`), reached through `FEngine move:to:`
(`FEngine.mm:225-229`). Its callers are `UCI.swift:87` and three test helpers
(`GameSessionTests.swift:29`, `MoveRowsTests.swift:20`, `UCIProcessTests.swift:88`). The last of
these, `isLegalMove`, therefore accepts some illegal moves, so the existing UCI test cannot catch an
illegal `bestmove`.

**P2 — The engine's own promotions are written without the piece.** `FPGN::to_string` returns
`from+to` for `SANType::uci` before it looks at the promotion (`Shared/Engine/Helpers/FPGN.cpp:152-154`).
So `bestmove` and the `pv` (`FEngineInfo.mm:86-101`) say `e7e8` where UCI requires `e7e8q`. A match
runner rejects that as illegal, and BChess loses the game.

**P3 — `go` ignores the clock.** `processCmdGo` (`UCI.swift:92-113`) looks only at the first
token. Anything other than `infinite` searches for a fixed 10 s (`// TODO time control`, `:104-106`).
That ignores `wtime/btime/winc/binc/movestogo/movetime/depth`, and a 10+0.1 game is lost on time
on move 1. A bare `go` crashes, because `tokens.removeFirst()` runs on an empty array (`:95`).

**P4 — Protocol details a runner trips over.**
- The first stdin line, whatever it is, triggers `id`/`uciok` (`UCI.swift:176-181`). A later `uci`
  falls to `default` (`:142-143`).
- An empty line crashes (`process` → `tokens.removeFirst()`, `:116`).
- Unknown commands, including `setoption`, which every runner sends, print `Unknown command …` to
  **stdout** (`:143`).
- `position fen` takes exactly six fields (`:63-65`). A FEN with fewer fields before `moves` crashes.
- `ucinewgame` does nothing (`:129-131`). That is harmless today, because `position` always calls
  `setFEN`, but the position is left from the previous game until then.
- `info` (`BChess/UCI/FENgineInfo+Extension.swift:15-31`) reports `time` in whole seconds of the
  last depth only (`IterativeDeepening.hpp:118`, `int(ms/1e3)`), but UCI's `time` is milliseconds
  since `go`. It also reports `depth` as `max(depth, quiescenceDepth)`, and gives a mate as
  `score cp 100000` (`ChessEvaluater.hpp:21`) instead of `score mate N`.

**What already works and is reused.**
- `FEngine evaluate:time:callback:` (`FEngine.mm:321-378`) arms a timer *when the search starts*
  (`:353-361`) and calls `stop`, so `time > 0` is the per-move budget.
- `stop` always lets depth 1 finish (`IterativeDeepening.hpp:154-159`), so the result is always a
  real move. `go` with no legal move answers `bestmove 0000` (`FENgineInfo+Extension.swift:33-40`).
- stdin is read on the main thread while callbacks print from the search queue (I4). The subprocess
  test `UCIProcessTests` (`BChessTests/UCIProcessTests.swift`) already drives the real binary.
- `UCI.swift` is compiled into `BChessTests` (`project.yml:121-122`), so pure functions placed in it
  can be unit-tested with no project change.
- The opening book is never loaded in the tool. `useOpeningBook = true` (`UCI.swift:31`) finds
  nothing, because only `GameSession` calls `loadOpening` (`Shared/Model/GameSession.swift:131`). So
  BChess plays its own moves from the first one, and an `OwnBook` option has nothing to switch.
- The transposition table is off (`FEngine.mm:64`, and the tool never sets `ttEnabled`). That stays
  as it is (see Decision 5).

## Design

### Step 1 — Legal moves from UCI text, and promotions written back (engine + bridge)

- **`ChessGame::move(std::string uciMove) -> bool`** replaces `ChessGame::move(from, to)`. It reads
  `from`, `to` and an optional promotion letter (`q r b n`), finds the one move in
  `ChessMoveGenerator::generateMoves(board)` with the same from, to and promotion piece, plays it
  with the existing `move(Move, "", false)`, and returns `true`. It returns `false` and changes
  nothing for a malformed or illegal token, including a pawn reaching the last rank without a
  letter. The legal move list already holds castling, en passant and every promotion. Matching
  against it replaces `ChessBoard::getMove`, which is **deleted** (`ChessBoard.cpp:364-389`,
  `ChessBoard.hpp:67`; no other caller). `ChessEngine::move(from, to)` (`ChessEngine.hpp:118`)
  becomes `bool move(std::string uciMove)`.
- **Bridge:** `- (BOOL)moveUCI:(NSString*)move NS_SWIFT_NAME(move(uci:))` replaces
  `move:to:` (`FEngine.h:83`, `FEngine.mm:225`), keeping the `[self invalidate]`. All four callers
  move to it; the three test helpers pass `from + to`. The result is one way to play a move from
  text, not two.
- **`FPGN::to_string(…, SANType::uci)`** appends the lowercase promotion letter
  (`FPGN.cpp:152-154`). `bestmove` and `pv` then carry `e7e8q`, and the `ChessGameTests.cpp:41`
  helper matches promotions too.

### Step 2 — UCI protocol hygiene (`BChess/UCI/UCI.swift`, `FENgineInfo+Extension.swift`)

- `uci` becomes a command in `process`: it prints `id name BChess`, `id author Jean Bovet` and `uciok`.
  `run()` stops treating the first line specially, so every line goes through `process`. No
  `option` lines are advertised (Decision 5).
- Empty and whitespace-only lines are ignored. `setoption`, `debug`, `register`, `ponderhit` and
  unknown commands are ignored on stdout and logged with `os_log`. (The UCI spec says to ignore
  unknown input.) After this, the only lines BChess prints are `id`, `uciok`, `readyok`, `info` and
  `bestmove`.
- `position`: the FEN is every token up to `moves` or the end of the line, so 4- or 6-field FENs
  both work. A FEN that does not parse (`setFEN` returns `NO`) leaves the start position and logs
  it. Each move goes through `engine.move(uci:)`; at the first `false`, the rest of the list is
  dropped and the problem is logged. No assert, no crash.
- `ucinewgame` calls `engine.setFEN(StartPosFEN)`.
- `info` keeps one line per completed depth, now in the standard form:
  `info depth D seldepth S score cp X|mate N time T nodes K nps P pv …`.
  - `depth` is `info.depth`, and `seldepth` is `max(depth, quiescenceDepth)`.
  - `time` is milliseconds since the `go` command. `UCI` keeps the `go` timestamp and passes it into
    `uciInfoMessage(elapsedMilliseconds:)`.
  - When `info.mat` is set, `score mate N` with `N = ±(pvPlies + 1) / 2` (engine POV), else
    `score cp`.
  - `uciInfoMessage` is also compiled into the apps (`project.yml:47,78`), but they never call it.
    `GamesTests.swift:120` uses only `uciBestMove`, which is unchanged.
- Dead code goes: `performance()` (`UCI.swift:147-153`), the commented tournament/performance blocks
  (`main.swift:11-12,15`, `UCI.swift:157-165`) and `write` (folded into `engineOutput`). The `xcode`
  command and the command-line-arguments mode stay. Neither writes extra lines to stdout, and a
  match runner uses neither.

### Step 3 — Time management (`go`)

A pure value type in `UCI.swift`, testable without a process:

```swift
nonisolated struct SearchLimits: Equatable, Sendable {
    var wtime, btime, winc, binc, movestogo, movetime, depth: Int?   // ms / count / plies
    var infinite = false
    init(goTokens: [String])          // key/value pairs; unknown keys (nodes, searchmoves, ponder, mate) skipped
    /// What FEngine.evaluate(_:time:) takes: depth -1 = unlimited, time 0 = no timer.
    func search(whiteToMove: Bool) -> (depth: Int, time: TimeInterval)
}
```

Allocation, all in ms, with `overhead = 50` and `minimum = 10`:
- `infinite`, or no clock and no movetime: no timer. `depth` if given, else unlimited. The search
  answers on `stop`, as now.
- `movetime m`: `max(m − overhead, minimum)`.
- Clock (`wtime`/`btime` for the side to move): `budget = remaining / (movestogo ?? 30) + inc`, then
  `min(budget, remaining − overhead)`, then `max(…, minimum)`. At 10+0.1 that is ≈ 433 ms on move 1,
  and it shrinks as the clock runs down.
- `depth d` also caps the depth when a clock or movetime is given.

`processCmdGo` parses the limits, records the `go` time, and calls
`engine.evaluate(depth, time:)`. The `stop`/`bestmove` path is unchanged.

**Hard limit only.** A finished budget aborts the depth in progress (`IterativeDeepening.hpp:154-159`)
and returns the last completed depth. There is no "don't start a new depth after half the budget"
rule (see Alternatives).

### Step 4 — Elo tooling (no app code)

- **`scripts/elo-match.sh`** (bash, `set -euo pipefail`). Its working directory is `.elo/` at the
  repo root, added to `.gitignore`. Nothing binary is committed.
  1. Checks its tools: `stockfish` (`brew install stockfish`, 19 today) and `fastchess`. If
     fastchess is not on `PATH`, the script uses `.elo/fastchess/fastchess` and, when it is missing,
     clones the **pinned release tag** of `github.com/Disservin/fastchess` and runs `make -j`. The tag
     is recorded in the script. There is no Homebrew formula (`brew info fastchess`: none).
  2. Fetches the opening book once: `8moves_v3.pgn` from `official-stockfish/books`, at a pinned
     commit URL, verified against a sha256 written in the script. A mismatch stops the script.
  3. Builds `BChessUCI` in Release with
     `xcodebuild -scheme BChessUCI -configuration Release -derivedDataPath .elo/dd build`.
  4. Plays one fastchess run per Stockfish level (`LEVELS`, default `1320 1600 1900`; 1320 is the
     lowest `UCI_Elo` Stockfish accepts). Each run is equivalent to:
     ```
     fastchess -engine cmd=<BChessUCI> name=BChess \
               -engine cmd=stockfish name=SF<L> option.UCI_LimitStrength=true option.UCI_Elo=<L> option.Threads=1 option.Hash=16 \
               -each tc=$TC timemargin=100 -openings file=8moves_v3.pgn format=pgn order=random \
               -repeat -games 2 -rounds $((GAMES_PER_LEVEL/2)) -concurrency $CONCURRENCY -recover \
               -draw movenumber=40 movecount=8 score=10 -resign movecount=4 score=1000 twosided=true \
               -pgnout file=.elo/runs/<stamp>/SF<L>.pgn
     ```
     The flag spellings are checked against the pinned version's `--help`. `-repeat` plays each
     opening with both colours. Defaults: `TC=10+0.1`, `GAMES_PER_LEVEL=134`, `CONCURRENCY=4` (the
     M2 has 4 performance cores; efficiency cores add noise). All are overridable through
     environment variables, since Jean will want to change them.
  5. Reports, for each level, W/D/L, score % and fastchess's Elo difference ± 95%. It also counts
     BChess losses by illegal move, time forfeit or disconnect from the PGN `Termination`. Any
     illegal move or disconnect marks the run **invalid**, because the number would measure a bug.
     A level scored above 90% or below 10% is flagged as uninformative.
  6. Gives an overall estimate: the inverse-variance weighted mean of `L + diff` over the levels,
     with its ± (in `awk`, no Python). It also prints a ready-to-paste Markdown row for `docs/elo.md`.
- **`docs/elo.md`** covers:
  - Method, and setup (three commands).
  - How to run, and how long it takes.
  - **Caveats:**
    - Stockfish's `UCI_Elo` is calibrated against CCRL 40/4 at a longer time control (60+0.6 in its
      documentation; confirm against the installed version), so 10+0.1 numbers are indicative.
    - The rating is relative to that anchor, not FIDE.
    - Engine weaknesses the number will reflect: no mate distance, so mates can drift into
      repetition; no TT; no fifty-move rule.
  - The error-bar table below.
  - A **Results** table: date, commit, TC, book, levels, games, W/D/L per level, estimate ± 95%,
    and wall time.

**Error bars** (95%, near a 50% score, about 20% draws; the per-game score variance is about 0.2,
and 1 score point ≈ 695 Elo at 50%):

| Games | ± Elo |
|------:|------:|
| 100 | ±61 |
| 200 | ±43 |
| 400 | ±31 |
| 1000 | ±19 |

Levels far from the true rating add less information, so the three-level fit over 400 games is
roughly ±35–45.

**Time on this Mac (M2, concurrency 4)**: a 10+0.1 game takes ≤ 2 × (10 + 0.1 × moves) s. With
adjudication, about 25 s of wall time is a reasonable estimate. 400 games × 25 s / 4 ≈ **40–45 min**.
At 60+0.6 the same 400 games take about 4–5 h.

### Step 5 — First measurement (default: run it)

Run `scripts/elo-match.sh` with the defaults (3 × 134 = 402 games, 10+0.1). Record the result in
`docs/elo.md` → Results, with error bars, wall time and the commit. Put a one-line summary in the
README row.
- If BChess scores above 90% against 1900, rerun with higher `LEVELS`.
- If it scores below 10% against 1320, use the fallback in Decision 2.
- An **invalid** run (illegal move, disconnect) is a bug to fix in steps 1–3, not a number to record.

### Reuse

- `ChessMoveGenerator::generateMoves` (legal moves) and `ChessGame::move(Move, …)`.
- `FEngine evaluate:time:callback:`, `stop` and its generation guard.
- `FEngineInfo` `mat`/`depth`/`quiescenceDepth`/`bestLine(true)`/`uciBestMove`.
- `UCIProcess` (the subprocess harness in `UCIProcessTests.swift`) and its `isLegalMove`, which
  becomes a real legality check through `move(uci:)`.
- `os_log` for diagnostics.
- No new files in the app targets, and no `project.yml` change.

## Alternatives rejected

- **Parse UCI moves in Swift against `engine.allMoves()`.** That fixes the tool but leaves
  `ChessBoard::getMove` building illegal or flagless moves for anything else. Fixing it in the engine
  is the same amount of code, and it is testable as plain C++ (I3).
- **Keep `move:to:` and add `moveUCI:` beside it.** That is two ways to play a move from text, one
  of them wrong for promotion and en passant. Replace it instead.
- **Soft time limit / "don't start a depth past 50% of the budget".** It saves clock but changes
  no move. It is a strength tweak for later, not needed for a correct engine.
- **Node limits (`go nodes`).** The search has no node counter check. The token is skipped, so a
  runner that uses node limits isn't supported (fastchess and cutechess default to clocks).
- **cutechess-cli as the runner.** It is also not in Homebrew, it needs Qt to build, and it is
  slower at high concurrency. fastchess builds with `make` alone and reports Elo±, illegal moves and
  timeouts directly. (Decision 1.)
- **The repo's `BChess/Openings.pgn` as the match book.** It holds variations and named lines of
  uneven length; fastchess plays mainlines only. `8moves_v3` is balanced, standard, and pinned by
  hash.
- **UHO books.** They are built to be unbalanced, to separate strong engines. At this level they
  mostly add noise.
- **Exposing `Hash`/`Threads`/`OwnBook`.** There is no book to own. The search is single-threaded.
  The TT stays off (Decision 5). An option nobody would change is a knob the simplicity bar rules out.
- **Running Elo in CI.** It takes tens of minutes and needs network tools. It is a manual measurement
  recorded in `docs/elo.md`.

## Test plan

Each test is written first and seen red on `main` + ENGINE-1.

| Step | Test | Proves | Red today |
|------|------|--------|-----------|
| 1 | `FEngineTests.moveUCIPlaysPromotionEnPassantCastling` (Swift): `b7b8n` from `8/1P6/8/8/8/8/8/k3K3 w - - 0 1` → FEN with a knight on b8; `e5d6` ep → captured pawn gone; `e1g1` → rook on f1; each returns `true` | legal-move matching, all three special moves | yes (no `move(uci:)`; ep leaves the pawn) |
| 1 | `FEngineTests.moveUCIRejectsIllegal`: `e2e5`, `b7b8` (no letter), `zz99`, `e7e8q` for a non-pawn → `false`, FEN unchanged | no silent illegal moves | yes |
| 1 | `MoveTests.UCIStringHasPromotion` (GoogleTest): `to_string(createPromotion(b7,b8,WHITE,PAWN,QUEEN), uci) == "b7b8q"`, knight → `"b7b8n"` | P2 | yes |
| 2 | `UCIProcessTests.promotionInPositionMoves`: `position fen 8/1P6/8/8/8/8/8/k3K3 w - - 0 1 moves b7b8q`, `go depth 1` → `bestmove` legal in `1Q6/8/8/8/8/8/8/k3K3 b - - 0 1` | P1 end to end, no crash | yes (assert) |
| 2 | `UCIProcessTests.bestMoveCarriesPromotion`: `8/1P6/8/8/8/8/8/k3K3 w` `go depth 3` → `bestmove b7b8q` | P2 end to end | yes (`b7b8`) |
| 2 | `UCIProcessTests.onlyUCILinesOnStdout`: `uci`, blank line, `setoption name Hash value 16`, `foo`, `isready`, `ucinewgame`, `position startpos moves e2e4`, `go depth 2`, then every line matches `^(id |uciok$|readyok$|info |bestmove )`, and the `bestmove` is legal for Black after e4 | P4, ucinewgame, no crash on blank | yes |
| 2 | `UCIProcessTests.mateIsReportedAsMate`: `6k1/5ppp/8/8/8/8/8/R5K1 w - - 0 1` `go depth 2` → an `info` with `score mate 1`, `bestmove a1a8` | `score mate` | yes |
| 3 | `SearchLimitsTests` (pure Swift Testing, new file in `BChessTests/`, picked up by the folder source): parse of `wtime 10000 btime 9000 winc 100 binc 100`, `movetime 500`, `depth 4`, `infinite`, `` (bare), unknown tokens skipped; allocation: 10+0.1 white → 433 ms, black uses `btime`, `movestogo 1` with 1000 ms → 950, 30 ms left → 10 (floor), movetime 500 → 450, depth-only → (4, 0) | the formula and its edges | yes (type missing) |
| 3 | `UCIProcessTests.clockIsHonoured`: `go wtime 3000 btime 3000` → `bestmove` within 1.0 s, legal | P3 | yes (10 s) |
| 3 | `UCIProcessTests.movetimeIsHonoured`: `go movetime 300` → `bestmove` after ≥ 200 ms and within 1.5 s | movetime | yes |
| 3 | `UCIProcessTests.depthEndsTheSearch`: `go depth 2`, no `stop` → `bestmove` within 5 s, and the last `info` has `depth 2` | depth honoured | yes |
| 3 | existing `goInfiniteThenStopPrintsBestMove`, `positionWithoutMovesPrintsTheNullMove` | `infinite`/`stop`/`0000` unchanged | — |

The process tests run in Debug, from positions outside any book, each in a few hundred ms, so the
suite stays well under 10 s. Step 4 has no unit test. Its check is a smoke run
(`LEVELS=1320 GAMES_PER_LEVEL=4 TC=2+0.05`) that must finish with no invalid game, reported in the
step's commit message.

## Invariants

- **I1 — Files keep opening.** Holds. PGN writing uses the SAN types, and only `SANType::uci` gains
  the letter. No stored format uses UCI text (`FEngineMoveNode.mm:27` uses `tight`).
- **I2 — Search results land on their position.** Holds. `move(uci:)` keeps `[self invalidate]`,
  and the app never calls it.
- **I3 — Portable engine.** Holds. Step 1 is plain C++ in `ChessGame.cpp`; one function is deleted
  from `ChessBoard.cpp`.
- **I4 — The UCI tool keeps working.** This is the invariant most at risk, and it is held:
  - stdin stays on the main thread, and callbacks print from the search queue.
  - `stop` and timers go through the existing generation guard.
  - Every new path (`go` parsing, illegal moves, blank lines) ends in "ignore and log", never an
    assert or an empty `removeFirst`.
  - The existing stop/0000 tests stay. The new process tests cover promotion, clocks, `movetime`,
    `depth`, `ucinewgame` and stdout cleanliness.
- **I5 — Private and offline.** Holds for the apps, which are unchanged. The Elo script downloads
  developer tools (fastchess source, the opening book) into the git-ignored `.elo/` only when run by
  hand. Nothing reaches the app or CI.

## Risks and rollout

- **Stockfish's calibration** at 10+0.1 is approximate. The number is reported with the TC, and
  Decision 3 offers the calibrated TC.
- **The engine may sit below 1320**, Stockfish's lowest level. Decision 2 has the fallback.
- **Root repetition.** In a position that already occurred three times, the search returns no move
  (`MinMaxSearch.hpp:152`), and BChess would answer `0000`. fastchess ends the game at threefold
  before asking, so this only matters if the two disagree on repetition. The match report counts
  disconnects and illegal moves, so a disagreement would show.
- **C++ `assert`s stay on in Release** (no `NDEBUG` in `project.yml`). That is slower, but correct.
  Turning them off is an app-wide build change, out of scope.
- **Machine load** during the match makes time forfeits more likely. `timemargin=100` and a
  concurrency of 4 keep them rare, and the report counts them.
- No device needed. The gates in `/develop` cover it, and step 5 runs on Jean's Mac.

## Decision left open for Jean

1. **Match runner.** Default: **fastchess** (builds with `make`, reports Elo± and forfeits).
   Alternative: cutechess-cli (needs a Qt build).
2. **Reference opponents.** Default: **Stockfish 19 with `UCI_LimitStrength`** at 1320/1600/1900,
   one `brew install`. Alternative (also the fallback if BChess is below 1320): add 1–2 small engines
   with published CCRL ratings, built from source into `.elo/`, e.g. ones rated about 1000–1400.
3. **Time control.** Default: **10+0.1** (≈ 40–45 min for 400 games, indicative). Alternative:
   60+0.6, Stockfish's calibration TC (≈ 4–5 h for 400 games).
4. **Games in the first run.** Default: **≈ 400** (±35–45 Elo overall), run as step 5 and recorded.
   Alternative: leave the run to Jean, or 1000 games (≈ ±20–25, ≈ 2 h).
5. **Transposition table.** Default: **off, as today** (the TT never clears, has no aging, and
   ENGINE-1 lists repetition/TT interactions as follow-ups). Alternative: a second run with `ttEnabled`
   on to see what it is worth, behind a `Hash` option. That only makes sense after the TT follow-ups.
