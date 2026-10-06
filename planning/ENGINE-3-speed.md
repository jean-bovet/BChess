# ENGINE-3 (speed) — A faster search at the same strength of play, measured

Revision 2 (2026-10-06). Planned on `main` (`--no-worktree`, Jean's call). This is the first of three
ENGINE-3 plans: **speed** (this one), then **search** (pruning, check extension, TT cut-offs and draws),
then **evaluation**. It assumes ENGINE-1 (bug fixes, perft) and ENGINE-2 (match-ready `BChessUCI`, mate
distance, `scripts/elo-match.sh`, 1736 ± 40 in `docs/elo.md`) and repeats neither.

- r1 — first draft.
- r2 — Codex plan round 1 (substantive). All findings accepted:
  - **Blocker.** The A/B mode validates against the number of games actually played. It accepts
    fewer than `MAX_GAMES` only when fastchess reports an SPRT decision.
  - Time forfeits by **either** engine make a run invalid, in both modes.
  - A failed TT allocation: checked size arithmetic, a test seam that forces the failure, and no
    retry on every store.
  - Delta pruning never skips a capture that gives check, so a mating capture is still searched.
  - SEE: pins are ignored (documented and tested), a king recapture into an attacked square is
    refused, and the PxN fixtures are corrected.
  - The GoogleTest registration floor is raised with every step that adds cases.
  - The board is passed as `ChessBoard &`, not `const`, because `getHash`, `isCheck` and
    `generateMoves` update caches.

Jean's request: "Start with the speed plan." The goal is a higher Elo through a faster search: more
depth in the same time. Out of scope here: new pruning of the main search (null move, LMR, futility),
check extensions, quiescence in check, the fifty-move rule, and any change to the evaluation. Those
belong to the search and evaluation plans.

## Problem, with evidence

All numbers were re-measured for this plan on an Apple M2 with a load average of 100–200 from other
projects. Wall-clock figures are therefore pessimistic. The retired-instruction counts quoted later
for the bench do not depend on load: two runs of the same loop gave 600,038,287 and 600,111,280
instructions.

- **Baseline, fixed-depth search.** A scratch bench (iterative deepening to depth 6, TT off as shipped,
  six perft positions and two middlegames) visits **13.69 M nodes in 8.4 s of CPU time** (1.6 M
  nodes/s). With the TT on it visits **9.34 M nodes (−32 %)** and gives the same scores and best moves
  on these positions.
- **Baseline, perft.** `planning/assets/ENGINE-1/perft.cpp`, built at `-O2`: start d5 4,865,609
  (17.3 Mnps under load). ENGINE-1 measured about 35 Mnps when the machine was idle. All six
  positions match the reference counts.
- **Memory.** The same bench at depth 5, TT **off**, has a **maximum RSS of 579 MB**. Two causes:
  - `TranspositionTable()` callocs `TRANSPO_SIZE+1` entries of 32 bytes, about 549 MiB, in its
    constructor (`TranspositionTable.hpp:14`, `:55-57`).
  - `MinMaxSearch::alphabeta` stores into the table **whether or not the TT is enabled**: the store at
    `MinMaxSearch.hpp:269-275` has no `config.transpositionTable` check, while the probe at `:161`
    does.

  So every search, including the app's default TT-off search, writes into a 549 MiB table. The table
  is never cleared. Every `FEngine` owns one (`ChessEngine.hpp:44` → `IterativeDeepening.hpp:51`),
  including the throwaway engines in `GameSession.paste` (`GameSession.swift:362`) and
  `GameState.swift:81`. A `calloc` failure is not handled (`TranspositionTable.hpp:56`), so on iOS
  this is a jetsam or null-dereference risk in the shipped app.
- **Profile** (`sample`, 6,266 top-of-stack samples, bench at depth 7, TT off):

  | Share | Where | Cause |
  |---:|---|---|
  | ~19 % | `stateKey` 555, `isEnPassantTargetValid` 353, `getPseudoNumber` 141, `getHash` 82, `getWhiteTurn` 59 | Hash upkeep inside `ChessBoard::move` (`ChessBoard.cpp:227-356`). `move()` also runs for **every pseudo-legal move** just to test legality (`MoveList::addSingleMove`, `MoveList.cpp:25-43`, copies the board, calls `move()`, then `isCheck`). That legality test pays for the hash and twice for `stateKey` (`ChessBoard.cpp:233`, `:355`), all of it thrown away. |
  | ~12 % | `ChessEvaluater::evaluate(…, MoveList)` 761 | The material and piece-square loop (evaluation plan). It also takes the `MoveList` (1 KB) and the board by value (`ChessEvaluater.hpp:42-43`). |
  | ~25 % | generation: `generateAttackMoves` 526, `isAttacked` 411, `generatePawnsMoves` 241, `addMove` 240, … | `generatePawnsMoves` calls `board.isEnPassantTargetValid(color)` once per pawn (`ChessMoveGenerator.cpp:193`), although the answer is the same for every pawn. |
  | ~9 % | `_platform_memmove` 367, `memset` 114, `Variation::push` 77, `chkstk` 41 | `MinMaxVariation::push` takes the child line (`MoveList` plus three ints, about 1 KB) by value (`MinMaxSearch.hpp:46`). `MoveList::push(MoveList)` does the same (`MoveList.hpp:39`). `Variation bestLine = (move == bestMovePV) ? bv : Variation();` copies or zero-fills 1 KB per move (`MinMaxSearch.hpp:243`). `pv.push(value, …, Variation())` does too (`:173`). `Variation()` value-initializes, which zero-fills the whole array. |
  | ~5 % | `isThreefoldRepetition` 238, `isDraw` 97 | `isDraw` runs up to three times on the same node at the horizon: `alphabeta` (`MinMaxSearch.hpp:178`), then `quiescence` (`:291`), then `evaluate` (`ChessEvaluater.cpp:158`). Every quiescence node pays two calls (`:291` plus `evaluate`). Each call copies the board and the `HistoryPtr` (`shared_ptr`, two atomic operations). The scan walks the whole history (`GameHistory.cpp:14`). |
  | ~3.6 % | `std::stable_sort` 127, `moveComparison` 97 | MVV/LVA sort through a function pointer (`ChessMoveGenerator.cpp:103-107`). |

  The bench starts every position with a one-entry history, so the cost of the repetition scan in a
  real game (a history of 100+ positions) does not show here. Step 1's bench adds a long-history
  position so that it does.
- **Move ordering.** The only ordering beyond MVV/LVA is the previous iteration's best variation `bv`.
  It is tried first at index −1 (`MinMaxSearch.hpp:203-229`), and only along the PV:
  `bestLine = bv` only when `move == bestMovePV` (`:243`). Every node off the PV gets no hash move
  and no killers. The ENGINE-1 performance review reported −29 % / −43 % nodes from TT-move and
  killer ordering. The −32 % measured above is the TT with cut-offs, not ordering alone.
- **Quiescence searches every capture.** There is no delta pruning and no SEE
  (`MinMaxSearch.hpp:304-342`). Stand-pat calls `evaluate(node, history)`, which generates moves in
  `firstMoveOnly` mode (`ChessEvaluater.cpp:140-143`) to detect mate and stalemate. That call is
  needed for exactness. See step 5.
- **Repetition is not bounded by the half-move clock.** The clock is maintained (`ChessBoard.cpp:239-243`,
  `:283-285`, `:338-339`) but unused. No position before the last capture or pawn move can recur, so
  the scan could stop `halfMoveClock` plies back.

## Design

There are two kinds of step, and each has its own gate. The gate is what makes a step safe to land
without a match.

- **Exact steps** (2–5) must not change what the search computes. The bench **signature** must be
  identical before and after: for every position, the node count, the score and the best move at the
  fixed depth. The perft counts must also be identical. The step lands only if the bench's retired
  instructions drop by at least 2 %. Otherwise it is dropped, and the drop is recorded in this plan.
- **Ordering steps** (6, 7) may change the node counts and, between equal-valued moves, the best
  move. They must not change any score. The bench runs with TT cut-offs off. Alpha-beta with a full
  root window then returns the exact minimax value whatever the move order (the principle behind
  `MinMaxSearchTests.SortingDoesNotChangeTheScore`), and the search's only path dependence is the
  repetition history, which does not depend on order. The step lands only if total bench nodes drop
  by at least 5 % and instructions per node do not rise by more than the nodes saved.
- **Value-changing steps** (8, 9) change scores, so the bench can say nothing about strength. They
  land only on an SPRT pass against the previous commit (Decision D3).

### Step 1 — Bench and A/B match tooling (no engine change)

- **`scripts/bench.sh` + `scripts/bench.cpp`.** The script builds standalone at `-O2 -DNDEBUG`
  against `Shared/Engine`, the same way ENGINE-1's perft harness is built (that build line,
  `ENGINE-1-engine-bugs-and-perft.md:291-293`, moves into the script). The positions are:
  - the six perft positions (reused from `planning/assets/ENGINE-1/perft.cpp`);
  - two middlegames, `r1bqkb1r/pppp1ppp/2n2n2/4p3/2B1P3/5N2/PPPP1PPP/RNBQK2R w KQkq - 4 4` and a
    quiet endgame (not a mate in one);
  - a **long-history position**: a game of 60+ moves built into the bench as UCI moves, played through
    `ChessGame` so that the search gets the real history.

  For each position the bench runs `IterativeDeepening::search` to a fixed depth (default 6;
  `DEPTH=`, `TT=0|1`) on a fresh engine. It prints the per-position line (nodes, score, best move) and
  then two totals:
  - the **signature**: total nodes, plus a hash of all the scores and best moves;
  - the **cost**: retired instructions and cycles (`proc_pid_rusage(RUSAGE_INFO_V4)`, macOS only,
    behind `__APPLE__`; this file is a developer tool outside `Shared/Engine`, so I3 holds), and CPU
    time.

  `REPEAT=5` reruns it and reports the minimum CPU time. `bench.sh --perft` runs ENGINE-1's
  `perft.cpp` (all six positions must say OK) and prints Mnps.

  The **baseline** (before step 2) is recorded in the "Results" table at the end of this plan, and
  every later step adds its row. Instructions are the speed metric. CPU time is reported but not
  trusted on a loaded machine, where threads also land on efficiency cores.
- **`scripts/elo-match.sh` gets an A/B mode:** `BASE=<git ref> scripts/elo-match.sh`.
  - **Build.** It builds `BChessUCI` (Release) from `git archive <ref>`, extracted into
    `.elo/base/<sha>` (git-ignored, cached by sha), next to the current checkout's build.
  - **Match.** fastchess plays `name=BChess` (the checkout) against `name=Base` (the ref). The
    command is the same as today, minus the Stockfish checks, plus
    `-sprt elo0=0 elo1=10 alpha=0.05 beta=0.05 model=logistic` and
    `-rounds $((MAX_GAMES / 2))` (default `MAX_GAMES=8000`). The default `TC=5+0.05`
    (Decision D3).
  - **Checks.** The per-game checks of the PGN validator (`pgn_summary`) are reused: the checkout's
    engine is still named `BChess`, so the W/D/L stay from BChess's side. Two things change, and the
    second applies to both modes:
    - **The expected game count.** An SPRT run can stop before `MAX_GAMES`. Today the run is invalid
      unless `PLAYED == GAMES` and `PGNGAMES == GAMES` (`elo-match.sh`, report section). In A/B
      mode the expected count becomes `PLAYED`, the games fastchess's summary reports. A run with
      `PLAYED < MAX_GAMES` is valid only when the log holds fastchess's SPRT decision line
      ("H0 was accepted" / "H1 was accepted"). `PGNGAMES` and the PGN's W/D/L must equal the
      summary's in every case. An even count is not required, because an SPRT can stop between the
      two games of an opening pair.
    - **Time forfeits by either engine.** Today `pgn_summary` counts only BChess's time-forfeit
      losses, and that count is not part of the invalid-run condition. It now counts `time forfeit`
      terminations whichever side lost, and any count above zero makes the run invalid (exit 2).
      This applies to the Stockfish mode too. A Base or Stockfish forfeit would otherwise inflate
      BChess's score. ENGINE-2's runs had none, so its recorded results stand. `docs/elo.md` says so.
  - **Result.** It reports fastchess's `LLR` line, then one of:
    - "H1 accepted" (exit 0);
    - "H0 accepted" (exit 4);
    - "inconclusive at MAX_GAMES" (exit 5), when all games were played with no decision;
    - an invalid run, exit 2, as today.

  `--self-test` gains these cases:
  - an early H1 stop: fewer games than `MAX_GAMES` and a decision line → valid;
  - an early H0 stop → valid, exit 4;
  - fewer games and **no** decision line → invalid;
  - PGN totals that differ from the summary → invalid;
  - a time forfeit lost by BChess, and one lost by the other engine → both invalid.

  The decision and summary parsing are shell functions, fed by small sample logs, like the existing
  PGN samples. `docs/elo.md` gains a short "A/B (SPRT)" section: how to run it, and how to read the
  result.

### Step 2 — Transposition-table memory: lazy, sized, and safe (exact)

- **Allocation.** `TranspositionTable(size_t megabytes = 16)` allocates nothing in its constructor.
  - The first `store` allocates a power-of-two number of entries that fits in `megabytes`, and the
    index becomes `hash & mask` instead of `hash % TRANSPO_SIZE`, so no division.
  - `exists`/`get` on an unallocated table return "absent".
  - **The size is checked before allocation.** The entry count is the largest power of two with
    `count * sizeof(TranspositionEntry) <= megabytes * 2^20`, computed so it cannot overflow:
    `megabytes` is clamped to `SIZE_MAX / 2^20` first, and the count is at least 1.
  - **A failed `calloc` disables the table for its lifetime.** A `bool allocationFailed` is set,
    every later store and probe returns at once without retrying the allocation, and the search
    works without a table.
  - **Test seam.** The allocator is called through a function pointer, `calloc` by default, that a
    test can replace with one returning `nullptr`. This makes the failure deterministic for a valid
    size. The seam is a static member behind `BCHESS_TEST_HOOKS`, the existing test-hook macro
    (`MinMaxSearch.hpp:72`). Release builds call `calloc` directly.
  - `TRANSPO_SIZE` goes away.
  - A `size_t allocatedBytes() const` is added for the tests.
- **Store replacement.** The entry gains a `uint8_t generation`. `IterativeDeepening::search` bumps
  the table's generation once per search. A store then replaces an entry when the generations differ
  **or** the new depth is at least the stored one. Today (`TranspositionTable.hpp:70`) deep entries
  from earlier moves of the game can never be replaced, because the table is never cleared, so the
  table fills with stale entries. Step 6 makes this matter, because it uses the table for ordering.
  - The TT tests that share one table across two `alphabeta` calls (`TTMateIsPlyRelative`,
    `TTBoundsUseRootRelativeMates`) do not go through `search()`. The generation stays the same, so
    their behaviour is unchanged.
- **Size per use.** `ChessEngine` and `IterativeDeepening` take a size, and `FEngine` passes it:
  - **16 MB on iOS** (`TARGET_OS_IPHONE` in `FEngine.mm`, which may use Apple headers; the engine
    stays portable, I3);
  - **64 MB on macOS** (app and `BChessUCI`);
  - nothing for engines that never search: the paste probe and the `loadAllGames` probe now cost no
    table, because allocation is lazy. No `Hash` UCI option (Decision D2).

  At 1.6 M nodes/s and about 0.3 s a move at 10+0.1, a search stores fewer than 0.5 M entries, so
  16 MB (512 K entries of 32 bytes) is enough.
- **The store at `MinMaxSearch.hpp:269` stays unconditional**, and from step 6 on that is
  deliberate: the table feeds move ordering in every mode. A comment says so. The TT **probe for
  cut-offs** stays behind `config.transpositionTable` (`:161`), and the default stays off
  (Decision D1).
- **Gate.** The signature with TT off is identical, because the table is written but never read.
  The bench's maximum RSS drops from 579 MB to about 64 MB plus the process baseline; it is
  recorded. With TT on, the signature may change, because a smaller table and the new replacement
  rule mean different collisions. That is reported, not gated.

### Step 3 — Cheaper make-move: legality without the hash, incremental state key (exact)

- **Legality test without hash work.** `ChessBoard::move(Move move)` gains a sibling used only by
  `MoveList::addSingleMove`: `ChessBoard::moveForLegality(Move)`, or a `template<bool UpdateHash>`
  behind the same body. It does the bitboard and state updates and skips `getHash()`, both
  `stateKey` calls and every `hash ^=`. There is still one body, so the rules (castling rook,
  en passant, promotion, castling rights) cannot drift apart. `addSingleMove` copies the board as
  before and only reads `isCheck` on the copy. A legality-only board has a stale hash. The copy is
  discarded, and the method's comment says so.
- **Incremental state key in `move()`.** Replace "XOR out `stateKey(*this)` … XOR in
  `stateKey(*this)`" (`ChessBoard.cpp:233`, `:355`) with:
  - **Castling part.** XOR the castling key of a right only when that right changes during the move.
    Compare the four flags before and after; at most four XORs, usually none.
  - **En-passant part.** Only when `enPassant != 0` before the move: XOR out the old file key if
    `canCaptureEnPassant` held before. Only when `enPassant != 0` after the move (a double push): XOR
    in the new file key if `canCaptureEnPassant` holds after. Both are rare, so the common move pays
    two compares.
  - `stateKey` and `canCaptureEnPassant` stay as they are. They remain the definition, used by
    `ChessBoardHash::hash` and by the tests.
- **Hoist `isEnPassantTargetValid(color)`** out of the pawn loop in `generatePawnsMoves`
  (`ChessMoveGenerator.cpp:193`): it is computed once per call.
- **Gates.** These must hold:
  - perft all OK, in both the standalone and the in-test version (`Perft.*`);
  - `Perft.HashMatchesFromScratchAtEveryNode`;
  - every `BoardHash.*` test, `StateKeysAreMaintainedIncrementally` included;
  - an identical bench signature;
  - Mnps and instructions recorded. ENGINE-1 measured the state key at 20–25 % of perft; the
    expectation is to get most of that back. Perft makes moves with the hash, so it measures the
    incremental key. The bench measures both changes.

### Step 4 — No large copies in the search (exact)

- `MinMaxVariation::push(int, Move, const MinMaxVariation &line)` and `MoveList::push(const MoveList &)`.
- `ChessEvaluater::evaluate(ChessBoard &, …, const MoveList &)`. The board is a non-const reference
  because `getHash`, `isCheck` and `generateMoves` update its caches (`ChessBoard.hpp:78-84`,
  `ChessMoveGenerator.hpp:40-44`); making them const is a wider refactor this plan does not need.
  The `MoveList` is passed by const reference, and the same goes for
  `evaluateAction` and `evaluateMobility`, which take a `MoveList` by value
  (`ChessEvaluater.hpp:45-52`).
- `MinMaxSearch.hpp:243`: pass the child either `bv` or a reference to one empty `Variation` (a
  `static const` in `MinMaxSearch`). No per-move copy, no zero-fill.
- `MinMaxSearch.hpp:173`: push an empty line without building a value-initialized temporary. For
  example, an overload `push(int score, Move move)` that sets `moves.count = 1`.
- Local `Variation` objects stay default-initialized, as they are today. `count = 0` suffices, and
  nothing reads past `count`.
- **Gate.** Identical signature. Instructions recorded. `memmove` and `memset` should drop out of
  the top of the profile.

### Step 5 — Draw checks: once per node, bounded by the half-move clock (exact)

- **Repetition is checked only in `alphabeta`** (`MinMaxSearch.hpp:178`), which runs it on every
  node before the horizon. The checks in `quiescence` (`:291`) and inside
  `evaluate(board, history, moves)` (`ChessEvaluater.cpp:157-161`) are removed. This is exact:
  - At the horizon, the node is the one `alphabeta` just checked.
  - Every quiescence move is a capture (`generateQuiescenceMoves` skips pushes and non-capturing
    promotions, `ChessMoveGenerator.cpp:203`, `:265`, `:331`, `:383`). Any position after a
    capture has fewer pieces than every earlier position, so it can never repeat one.
  - `evaluate`'s other callers are the no-quiescence leaf, which `alphabeta` also checked first, the
    mate/stalemate branch, which returns before the draw check, and tests with a fresh history.

  `evaluate` then no longer needs the history. Its `HistoryPtr` parameter is removed and the
  callers are updated: `MinMaxSearch.hpp` (3) and `EvaluationTests.cpp:131-135`,
  `MinMaxSearchTests.cpp:37`, `:68`.
- **Bounded scan.** `ChessHistory::isThreefoldRepetition(hash, halfMoveClock, history)` stops after
  `min(halfMoveClock, size − 1)` plies back. This is sound:
  - The clock resets on every capture and pawn move (`ChessBoard.cpp:283-285`, `:338-339`), and no
    position before such a move can recur.
  - A lost castling right does not reset the clock, but it changes the hash, so the bound is still
    only an upper limit.
  - A FEN can claim a clock larger than the history; the `min` handles it.

  `ChessEvaluater::isDraw(ChessBoard &, const HistoryPtr &)` passes `board.halfMoveClock`.
  `ChessEngine::gameEnd` (`ChessEngine.hpp:157`) goes through the same function, so the game's draw
  detection gets the same bound. Today's semantics are kept: three occurrences, counted on the same
  side to move.
- **`HistoryPtr` by `const &`** through `alphabeta`, `quiescence`, `isDraw` and
  `isThreefoldRepetition`. That is no atomic refcount traffic per node. The object stays shared,
  and the search still pushes and pops on it.
- **`firstMoveOnly` in stand-pat stays.** It is what makes a mated or stalemated quiescence node
  score correctly (`ChessEvaluater.cpp:146-155`), and ENGINE-2's mate scores rely on it. It is
  cheap: generation stops at the first legal move, and after step 3 that legality test no longer
  pays for the hash. The implementer reports its profile share after this step. If it is above 5 %,
  the only allowed change is one that keeps the result exact, and it goes in as its own commit with
  the same gates: when the capture list is generated and non-empty, there is a legal move, so the
  `firstMoveOnly` call is skipped.
- **Gate.** Identical signature, including on the long-history position. Instructions recorded,
  with the long-history position's share shown separately.

### Step 6 — Hash move first, in every mode (ordering)

- **Order.** At each `alphabeta` node, after `sortMoves`:
  1. the `bv` move at this ply, if it is valid (as today);
  2. otherwise the **TT entry's `bestMove`** for `node.getHash()`, when an entry exists.
- **Validation.** The move must be found in the generated list. It is moved to index 0 there, so a
  colliding or stale entry can never play an illegal move.
- **The index −1 pass goes away.** The first move is simply at index 0, and the "skip it when met
  again" check (`MinMaxSearch.hpp:225-228`) goes with it. The `bv` line is still passed to the
  child of the `bv` move only.
- **Probing for ordering ignores `config.transpositionTable`.** That flag now gates only cut-offs.
- **`config.sortMoves = false`** turns off the hash move as well. "Unsorted" stays a real baseline,
  and `SearchChessTests.OrderedMove`'s unsorted count (341,658) is unchanged.
- **Gate.** Same scores on every bench position at the fixed depth, TT cut-offs off. Total nodes
  −5 % or better. With TT on, nodes are reported.

### Step 7 — Killer moves (ordering)

- **Storage.** `MinMaxSearch` keeps two killers per ply: `Move killers[MAX_PLY][2]`,
  `MAX_PLY = 128`, with plies ≥ `MAX_PLY` simply not using killers. They are cleared by
  `IterativeDeepening::search` at the start of a search and kept across its iterations.
- **Recording.** A quiet move that causes a beta cut-off in `alphabeta` (not a capture, not a
  promotion) becomes killer 0 at its ply, and the old killer 0 moves to slot 1, unless the move is
  already killer 0.
- **Order.**
  1. the hash move;
  2. captures by MVV/LVA;
  3. the killers that appear in the list, in slot order;
  4. the remaining quiet moves.

  The killers are moved to the front of the quiet segment after the sort. `sortMoves = false` turns
  killers off too.
- **History heuristic: only if it pays.** The implementer measures a from/to history table
  (`int history[2][64][64]`, incremented by depth² on a quiet cut-off, used to sort the remaining
  quiet moves). It goes in as a separate commit only if it takes another 5 % of bench nodes off
  without raising instructions per node by more than it saves. Otherwise it is dropped and recorded.
- **Gate.** Same as step 6.

### Step 8 — Delta pruning in quiescence (value-changing)

- **The rule.** In `quiescence`, skip a capture when all of these hold:
  - `stand_pat + pieceValue(captured) + 200 <= alpha`;
  - the move is not a promotion;
  - `alpha` is not a mate score (`ChessEvaluater::isMateScore`);
  - **the move does not give check.**

  `pieceValue` is a public accessor over the existing `PieceValue` table (`ChessEvaluater.cpp:88`);
  no second table.
- **Why the check exemption.** A capture can mate even when it wins little material. Without the
  exemption, delta pruning would skip it, and the `firstMoveOnly` mate check would never see the
  position after it. Keeping mates is worth more than a few saved nodes.

  The test is cheap and exact. The capture is made on the copy `quiescence` already builds
  (`MinMaxSearch.hpp:320-321`), then `newNode.isCheck(newNode.color)`. Only when that is false and
  the delta condition holds is the recursive `quiescence` call skipped. The recursive call
  (evaluation, generation, legality tests) is the cost delta pruning saves, so skipping it after
  the move keeps nearly all the saving.
- **What does not change.**
  - `bestValue` still starts at `stand_pat` and is still the maximum over the moves searched. The
    ENGINE-1 fixes keep holding: never below stand-pat, and the best capture rather than the last
    one.
  - Mates are still found by the `firstMoveOnly` check at each quiescence node that is searched,
    and every checking capture is searched.
  - The margin, 200 cp, is not tuned here.
- **Gate.** SPRT against step 7's commit passes (D3). The step adds nodes-per-depth and instruction
  figures to the results table.

### Step 9 — Losing captures pruned by SEE (value-changing; optional)

- **SEE.** A static exchange evaluation, `int ChessEvaluater::see(ChessBoard &, Move)` (or in
  `ChessBoard`), on one square:
  - attackers found with the same lookups `isAttacked` uses (`ChessBoard.cpp:484-520`);
  - x-rays uncovered through the magic lookups with an updated occupancy;
  - least valuable attacker first.
  - **Pins are ignored.** A pinned piece counts as an attacker or defender. This is the usual SEE
    approximation, and SEE only decides whether quiescence skips a capture, so a misjudged exchange
    costs a pruning decision, never legality: the moves searched still come from the legal
    generator. A test pins this behaviour down so that it cannot change silently.
  - **The king recaptures only into safety.** A king is the last attacker taken for its side. It
    may capture only when the opponent has no attacker left on the square after the exchange so
    far. Otherwise the exchange stops before the king's capture, because that capture would be
    illegal.
- **Pruning.** In `quiescence`, captures with `see < 0` are skipped, except promotions. They can
  also be sorted below winning captures; sorting them is part of the same commit.
- **The step is attempted only if step 8 landed**, and lands only on an SPRT pass against step 8's
  commit. Otherwise it is dropped and recorded (D4).
- **Gate.** SPRT pass. Plus `see` unit tests, listed in the test plan.

### Step 10 — Measurement and record

- **Whole-plan A/B.** `BASE=2eb86d5 scripts/elo-match.sh`, that is ENGINE-2 as landed against this
  plan's HEAD, SPRT [0, 10]. The result goes in this plan's results section.
- **Stockfish.** `LEVEL=<chosen> GAMES=300 scripts/elo-match.sh` at 10+0.1, with the level picked by
  a short probe as in ENGINE-2. One row is added to `docs/elo.md`'s results table, plus a sentence
  on what changed (speed only, TT cut-offs still off).
- **Bench.** The bench's results table (baseline and every step) is completed in this plan.
  `docs/elo.md` "Caveats" is updated: the TT now orders moves but does not cut off.

### Reuse

- **Hash.** `ChessBoardHash::stateKey` / `canCaptureEnPassant` stay the definition, used by `hash()`
  and the tests. `ChessBoard::isEnPassantTargetValid` is reused.
- **Variations and the table.** `MinMaxVariation` and the `bv` mechanism are kept. The existing
  `TranspositionTable` store and probe are extended.
- **Values.** `ChessEvaluater::PieceValue` (accessor), `isMateScore`, `mateAtPly`.
- **Tools.**
  - ENGINE-1's `perft.cpp` and its build line (moved into `scripts/bench.sh`, not copied).
  - `scripts/elo-match.sh`'s tool checks, PGN validator, `.elo/` layout and report.
  - fastchess's built-in `-sprt` (`.elo/fastchess/app/src/cli/cli.cpp:296-312`; models `logistic`,
    `normalized`, `bayesian`).

## Alternatives rejected

- **Turning TT cut-offs on by default in this plan.** It would be the biggest single node saving
  (−32 % measured). But it changes search results, and the ENGINE-1 follow-ups say the TT is still
  unsafe with draws: a repetition 0 is stored and reused on another path, and the probe runs before
  `isDraw`. Those fixes are search work. Ordering from the table gives most of the benefit with no
  change in value. → D1.
- **Clearing the table at each search instead of a generation byte.** Simpler, but with a 64 MB
  table, clearing costs on every move. It would also throw away entries the next move's search can
  use for ordering.
- **A pseudo-legal generator with legality checked when a move is made.** It would save more than
  step 3, but it changes the generator's contract, which perft, `gameEnd`, the UI's `movesAt` and the
  tests all rely on. It is out of proportion for this plan.
- **Removing `firstMoveOnly` from stand-pat outright.** Mated or stalemated quiescence nodes would
  then score as material, which breaks mate scores in quiescence (ENGINE-2). Rejected; step 5 keeps
  it, with an exact fallback.
- **A `Hash` UCI option now.** ENGINE-2 Decision 5 advertises no options, and with cut-offs off the
  size barely matters. → D2.
- **A `bench` command in `BChessUCI`** (as Stockfish has). It would need a bridge method and Swift
  timing code for a developer tool. A standalone C++ harness reuses the perft build and keeps the
  engine's portable path exercised.
- **SPRT on every step.** At 5+0.05 an SPRT [0, 10] takes 1–3 hours. Exact steps cannot change the
  play at a fixed depth, and ordering steps cannot change any score, so the bench proves them; one
  SPRT for the plan covers their combined gain. → D3.
- **A faster sort (`std::sort` on a precomputed key).** It is 3.6 % of the profile and changes the
  order between equal keys, which would make step 4's signature gate meaningless. Left for later if
  it shows up again.

## Test plan

Tests come first (AGENTS.md). Engine tests are GoogleTest cases. Every one is listed with what it
proves and whether it is red before its step.

| Step | Test | Proves | Red before? |
|---|---|---|---|
| 1 | `scripts/bench.sh` runs and prints a signature. `scripts/elo-match.sh --self-test` covers: an early H1 stop (valid); an early H0 stop (valid, exit 4); fewer games than `MAX_GAMES` with no decision line (invalid); PGN totals that differ from the summary (invalid); a time forfeit lost by BChess and one lost by the other engine (both invalid); inconclusive at `MAX_GAMES` (exit 5). | Tooling: an early SPRT stop is accepted only with a decision, and forfeits are never counted as results | the forfeit and early-stop cases are red against today's script |
| 2 | `TranspositionTableTests.LazyAllocation`: a new table has `allocatedBytes() == 0` and `exists()` is false. After one `store`, `allocatedBytes()` is a power of two ≤ the requested MB. | Probe engines cost no memory | yes (allocates 549 MiB in the constructor) |
| 2 | `TranspositionTableTests.NewSearchReplacesDeeperStaleEntry`: store a depth-8 entry, bump the generation, store depth 2 at the same index → replaced. Same generation → kept. | Stale entries do not block ordering | yes |
| 2 | `TranspositionTableTests.FailedAllocationIsHarmless`: a valid 1 MB table, with the `BCHESS_TEST_HOOKS` allocator seam returning `nullptr` and counting its calls. 1,000 stores are ignored, probes are absent, the allocator is called exactly once, and a depth-3 search with that table returns a legal move. | Reliability, no retry per node | yes (null dereference) |
| 2 | `TranspositionTableTests.SizeIsCheckedAndPowerOfTwo`: 1 MB → 32,768 entries (32-byte entries) or the equivalent for the final entry size. `SIZE_MAX` MB is clamped without overflow: the computed count is a power of two and its byte size does not wrap. The allocation is not attempted, because the seam records the request size and returns `nullptr`. | Checked arithmetic | yes |
| 2 | Swift `FEngineTests.ProbeEngineAllocatesNoTable`, through an `FEngine+Testing.h` accessor: a fresh `FEngine` reports 0 bytes. After a depth-2 search it reports the platform size (16 MB on the iOS test run, 64 MB on macOS). | Per-platform size, lazy in the app | yes |
| 3 | Existing `Perft.*` (6 positions + 2 castling cases), `Perft.HashMatchesFromScratchAtEveryNode`, all `BoardHash.*` | Move generation and hash unchanged | guards |
| 3 | `BoardHash.LegalityMoveLeavesRulesIntact`: for every pseudo-legal move of Kiwipete and position 4, the legality-only path and `move()` leave identical `pieces`, `enPassant`, castling flags and counters. | The two paths share one rule set | yes (no such path) |
| 4 | Existing `MinMaxSearch.*`, `SearchChess.*`, `IterativeDeepening.*`, `BestMove.*` unchanged | Exact | guards |
| 5 | `ChessGameTests.RepetitionIsBoundedByTheHalfMoveClock`: a hand-built history whose earlier occurrences sit behind a pawn move (positions that real play cannot produce: the same hash before and after a pawn move). Not a repetition with the bound, a repetition without it. | The bound is applied | yes |
| 5 | `ChessGameTests.RepetitionAfterManyReversibleMoves`: knights shuffled 40 plies, so the threefold still comes from the last 8 plies, and a FEN with clock 90 and a one-entry history does not read out of range. | Bound is sound, `min` handles FEN clocks | no (guard; ASan/Debug assert on `at()`) |
| 5 | Existing `ChessGameTests` lines 164/170 (`isDraw`), `EvaluationTests` (signature updated) | | guards |
| 6 | `MinMaxSearchTests.OrderingDoesNotChangeTheScore`: TT cut-offs off, `IterativeDeepening` to depth 4 on Kiwipete and two middlegames, with `sortMoves` on (MVV/LVA + hash move, + killers after step 7) and off. Same score at every depth. | Ordering stays value-neutral. The node saving is proven by the bench gate, not by a unit test. | no (guard) |
| 6 | `MinMaxSearchTests.BogusHashMoveIsIgnored`: store, under the root hash, an entry whose `bestMove` is illegal in the root position. Search depth 3 with TT cut-offs off. The PV's first move is legal, and the score equals a fresh-table search. | Validation against the list | not before step 6, where nothing reads the move. Proven red by deleting the validation in a scratch copy, then restored. |
| 6, 7 | `SearchChessTests.OrderedMove` / `ChessTree`: the sorted node counts are updated (the score, 50 / 0, unchanged). The unsorted counts (341,658 / 142,400) are **unchanged**. | `sortMoves=false` is still the plain baseline | n/a (recorded) |
| 7 | `MinMaxSearchTests.KillerIsAQuietMove`: after a search, killers hold only non-captures and non-promotions, at most 2 per ply, distinct. | Killer bookkeeping | yes |
| 8 | `MinMaxSearchTests.QuiescenceReturnsTheBestCapture`, `QuiescenceNeverBelowStandPat`, `MateCarriesDistance`, `PrefersShorterMate` unchanged. New `DeltaPruningKeepsAWinningCapture`: a position where a queen capture lifts the score above alpha keeps it. `DeltaPruningSkipsHopelessCapture`: a pawn capture far below alpha visits fewer quiescence nodes, same result. `DeltaPruningKeepsAMatingCapture`: the side to move is far behind (alpha well above stand-pat + pawn + 200), and a pawn capture mates (the implementer builds the FEN and confirms the mate with Stockfish). Quiescence at `maxDepth = 0` returns the mate score `MAT_VALUE − 1`, with that capture as the PV. | No regression of the ENGINE-1/2 fixes; a mating capture is never pruned | the last two are red (the last with the check exemption deleted in a scratch copy) |
| 9 | `SEETests`: PxN, knight undefended = **+320**; PxN, knight defended by a pawn = **+220** (320 − 100); QxP defended by a pawn = −800; an x-ray rook battery on a file; an en-passant capture = +100; a king capturing an undefended piece = its value. **King recapture refused:** a piece captured on a square the capturer's side still attacks after the exchange, where the only defender is the king → the king does not recapture, and the value is the full piece. **Pins ignored:** a capture defended only by a pinned piece is scored as defended, the documented approximation. | SEE values and the two exchange rules | yes |
| every step that adds GoogleTests | `EngineGoogleTests.registersAllCases` (`EngineGoogleTests.swift:30`, today `>= 166`) is raised to the new total in the same commit. | New cases cannot silently fail to register | n/a (floor) |
| all | Changed best-move tests: the ENGINE-1 rule (Stockfish depth 20, within 30 cp and not worse than the old line), documented in the commit. Stop only if a test's purpose fails. | | |

CI time: the new tests search at depth ≤ 4 (ms at `-O0`). The bench and matches are developer tools
run by the implementer, not in CI.

## Invariants

- **I1 (files keep opening).** Not applicable. No file format or parsing changes.
- **I2 (a result lands only on its position).** Holds. The search lifecycle, `_generation` and
  callbacks are untouched. The lazy allocation happens inside `search()` on the engine's serial
  queue, the only thread that touches the table.
- **I3 (portable engine).** Holds, and is at risk only in the obvious place: the per-platform size is
  chosen in `FEngine.mm`, never with a `TARGET_OS` check in `Shared/Engine`. `scripts/bench.cpp` uses
  `libproc` behind `__APPLE__` and is not part of the engine. The standalone bench build is itself a
  check that `Shared/Engine` compiles as plain C++.
- **I4 (UCI keeps working).** Holds. No protocol change, no new option (D2). `BChessUCI` gets the
  64 MB table, allocated lazily on the first `go`.
- **I5 (private and offline).** Holds. The A/B mode builds the base from the local git history.
  fastchess and the opening book are fetched as today, by the developer script only.

## Risks and rollout

- **iOS memory.** It goes from up to 549 MiB touched to 16 MB. Confirm once on a real iPhone: play a
  game with long analysis and check the memory gauge in Xcode. Owed, like APP-1's device checks.
- **Mate scores through ordering.** Ordering steps cannot change scores (gate), and
  `MateCarriesDistance` / `TTMateIsPlyRelative` are guards. Delta pruning is disabled when alpha is a
  mate score, and never skips a promotion.
- **SPRT cost.** It is several hours of machine time for steps 8–10 on a loaded machine. Running
  with `CONCURRENCY=4` on the performance cores is still right. On a busy machine the time control
  is effectively shorter for both engines alike. Since the A/B is self-play, that cancels out, but
  time forfeits must stay at zero (the validator refuses the run otherwise).
- **A step that does not pay is dropped, not forced.** Every drop is recorded in the results table
  with its numbers.
- **Node-count tests.** `SearchChessTests` asserts exact counts. They change in steps 6–9 and are
  updated with the old and new values in the commit message. The scores stay.

## Decisions left open for Jean

- **D1 — TT cut-offs on by default:** in this plan, or in the search plan? **Recommended: the search
  plan.** This plan uses the table for move ordering in every mode, which does not change any score.
  Turning cut-offs on changes values and needs the draw/TT fixes listed in ENGINE-1's follow-ups
  first. The app setting "Use Transposition Table (Beta)" (`SettingsView.swift:18`) keeps its meaning.
- **D2 — Table size:** **recommended 16 MB on iOS, 64 MB on macOS** (app and UCI), lazily
  allocated, and no `Hash` UCI option until the search plan turns cut-offs on. Alternative: advertise
  `option name Hash type spin default 64 min 1 max 1024` now (ENGINE-2 Decision 5 said no options).
- **D3 — Strength gate:** **recommended** as follows. Exact and ordering steps are gated by the bench
  (identical signature / identical scores and fewer nodes), and each value-changing step (8, 9) by an
  SPRT against the previous step:
  - `elo0=0 elo1=10 alpha=0.05 beta=0.05 model=logistic`;
  - TC 5+0.05, at most 8,000 games, concurrency 4;
  - plus one whole-plan SPRT and the Stockfish row at the end.

  Alternatives: SPRT every step, about 2 hours each; or a non-regression test `[-5, 0]` instead of a
  gain test for steps 8–9.
- **D4 — SEE (step 9):** **recommended: attempt it after delta pruning, keep it only on an SPRT
  pass.** Alternative: skip it in this plan and leave it to the search plan.

## Results (filled in by the implementer)

| Step | Commit | Signature (nodes / scores hash) | Instructions | Δ instr. | Perft Mnps (start d5) | Max RSS | SPRT | Landed? |
|---|---|---|---:|---:|---:|---:|---|---|
| baseline | 2eb86d5 | | | | | | — | — |
