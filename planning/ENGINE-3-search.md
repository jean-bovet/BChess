# ENGINE-3 (search) — Correct draws and a pruned search, measured

Revision 3 (2026-10-07). Planned in the worktree `.claude/worktrees/engine-3-search` (branch
`engine-3-search`, from `main` 4986ad7). This is the second of three ENGINE-3 plans: speed
(`ENGINE-3-speed.md`, implemented), **search** (this one), then evaluation. It assumes ENGINE-1
(perft, bug fixes), ENGINE-2 (match-ready `BChessUCI`, mate distance) and ENGINE-3 speed (bench, A/B
SPRT, lazy table, TT-move and killer ordering, delta pruning) and repeats none of them.

- r1 — first draft.
- r2 — Codex plan round 1 (substantive). All nine findings were accepted; see "Review round 1 (Codex)"
  at the end. In short:
  - TT cut-offs are now called what they are, a standard approximation for path-dependent draws, with
    a test that pins down the known limitation.
  - Quiescence keeps the history and checks both draw rules.
  - PV nodes are an explicit parameter, which removes the window overflow.
  - The null move leaves the clock alone.
  - Futility has a storage policy.
  - The ply-guard tests go through the starting-ply seams.
- r3 — Codex plan round 2 (substantive). All five findings were checked against the code and accepted;
  see "Review round 2 (Codex)". In short:
  - Quiescence's draw checks also run when the history is unknown.
  - The null move comes after the node is known to have a legal move.
  - PVS's exactness gate turns delta pruning off.
  - The live-material and extension-bound tests now test what they claim.

Jean's request: the search plan. Two parts:

- **Correctness**, proven by tests that fail first, no SPRT:
  - the fifty-move rule and insufficient material;
  - a transposition table that is safe to cut off with;
  - quiescence while in check;
  - the ENGINE-1 horizon case.
- **Strength**, each step gated by the A/B tooling that speed built. The steps are TT cut-offs, check
  extension, null move, late-move reductions, PVS and aspiration windows, with futility and SEE pruning
  as options.

Out of scope: the evaluation (material, piece-square tables, `positionalAnalysis`, the
`MoveList::addMoves` colour tag from ENGINE-1's follow-ups), time management, and any UCI option.

## Problem, with evidence

All line numbers are at 4986ad7.

- **No fifty-move rule.** `ChessBoard::halfMoveClock` is maintained by `applyMove`
  (`ChessBoard.cpp:261-263`, reset at `:305` and `:363`) and written to the FEN (`FFEN.cpp:140`).
  Nothing in the search reads it. A won ending that is drawn by the fifty-move rule scores as won.
- **No insufficient material.** `ChessEvaluater::evaluate(board, moves)`
  (`ChessEvaluater.cpp:149-205`) returns material plus square bonuses. So K+B v K scores +330 and K+N v
  K scores +320, and the engine will trade into such an ending as if it were winning.
- **The root can be "drawn".** `alphabeta` runs `isDraw` on every node, the root included
  (`MinMaxSearch.hpp:246`), and returns 0 with an empty PV. `IterativeDeepening::search` then stops
  with no move (`IterativeDeepening.hpp:156`). The app never searches such a root, because
  `ChessEngine::gameEnd` (`ChessEngine.hpp:158`) blocks play. A UCI GUI can still send one. With a
  fifty-move rule added the same way, a GUI that sends a high clock would get no `bestmove` move.
- **The table is unsafe for cut-offs.** Three reasons, of which this plan fixes the first and the third,
  and only narrows the second (step 3):
  - The TT probe (`MinMaxSearch.hpp:227-242`) runs **before** `isDraw` (`:246`). A position that is a
    threefold on this path returns the table's value instead of 0.
  - A value that depends on the path is stored as if it belonged to the position. A child that
    returned a repetition 0 makes its parent store an `EXACT`, `ALPHA` or `BETA` value
    (`MinMaxSearch.hpp:341-347`) built on that 0. The value is then reused on another path, where the
    repetition does not exist. The fifty-move rule adds the same problem, since `halfMoveClock` is not
    in the hash.
  - The root can be cut off by the table (`MinMaxSearch.hpp:237-240`), which leaves a one-move PV
    (`pv.push(value, entry.bestMove, emptyLine)`).

  These are the ENGINE-1 follow-ups that speed's D1 deferred to this plan. The shipped engine has
  cut-offs off (`FEngine.mm:78` `_ttEnabled = NO`, `SettingsView.swift:12` default false). Tests run
  with them on, because `Configuration::transpositionTable` defaults to `true` (`MinMaxSearch.hpp:35`).
- **Quiescence stands pat in check.** `quiescence` (`MinMaxSearch.hpp:362-423`) always takes
  `evaluate(node)` as a lower bound. The `firstMoveOnly` generation inside `evaluate` catches mate, but
  a side in check that has legal moves is scored as if it could decline to move. A knight fork with
  check is scored as material, before the fork has taken anything.
- **The horizon case (ENGINE-1 step 4).** The test is `BestMoveTests.KnightEscapeAttackByPawn`
  (`BestMoveTests.cpp:102-114`), from `r1bqkbnr/pppp1ppp/2n5/3P4/8/8/PPP2PPP/RNBQKBNR b KQkq - 0 4`.
  Today it needs depth 5, and its comment records why depth 4 fails. Measured for this plan, against
  Stockfish 19 at depth 18 (MultiPV):

  | Search | Move | Stockfish |
  |---|---|---:|
  | today, depth 4 | Nc6-b4 | −159 |
  | depth 4 + check extension (scratch prototype) | Qd8-e7+ | −116 |
  | today, depth 5 | Nc6-e5 | −89 (best) |

  The other moves Stockfish rates: Ne7 −99, Nb8 −105, Bb4+ −559. Check extension brings depth 4 within
  30 cp of the best move, which is the ENGINE-1 judge rule. The prototype doubled the depth-4 nodes
  (15,075 → 29,781). Quiescence in check alone cannot fix this: the horizon falls after `Ne2`, with
  Black to move and not in check.
- **The search is plain alpha-beta.** It has a full window at every iteration
  (`IterativeDeepening.hpp:115`), no zero-window searches, no null move, no reductions and no
  extensions. Depth is counted from the root, and the horizon is `depth == config.maxDepth`
  (`MinMaxSearch.hpp:224`, `:250`). An extension or a reduction therefore has nowhere to go: step 1
  makes the remaining depth a parameter.
- **Baseline bench**, measured for this plan with `scripts/bench.sh`'s build flags at 4986ad7 (one run,
  load average about 3):

  | Depth | TT cut-offs | Nodes | Signature | Instructions |
  |---|---|---:|---|---:|
  | 6 | off (shipped) | 2,214,483 | 738f8a9f29c38a0d | 11,794,137,138 |
  | 6 | on | 1,680,703 (−24 %) | da333c334f93cd8f | 7,749,765,139 |
  | 7 | off | 11,424,038 | bba55faa494a84d2 | 38,482,037,374 |
  | 7 | on | 6,416,880 (−44 %) | 7f1559b2edd87b51 | 22,324,250,011 |

  The depth-6, TT-off figures equal speed's step-8 row, so the UI commit changed nothing in the engine.

## Design

There are three kinds of step, each with its own gate (the same scheme as speed's):

- **Exact steps** (1, 3): the bench signature stays identical, TT off. Step 1 must also keep it
  identical with TT on.
- **Rule steps** (2, 4): they change values only where a chess rule says the old value was wrong. They
  land when their red-first tests pass and the gates are green. The bench is recorded, not gated. Per
  Jean, no SPRT for these. The whole-plan SPRT (step 13) covers their combined cost.
- **Value-neutral search step** (6, PVS): with a full root window, PVS returns the same root value as
  alpha-beta, whatever the order. The bench gate is the one speed used for ordering steps: the same
  score on every position, TT cut-offs off, and total nodes at least 5 % lower. Otherwise the step is
  dropped and recorded.
- **Value-changing steps** (5, 7–12) land only on an SPRT pass against the previous commit (D3).

Each step is one commit. Each new `Configuration` flag has a test that turns it off, which is its second
caller, the same way `deltaPruning` is used.

### Step 1 — Ply and remaining depth (exact)

- **The new signature.** The private `alphabeta` takes `ply` (from the root) and `depthLeft`, instead of
  one `depth` compared with `config.maxDepth`:
  - the horizon is `depthLeft <= 0`;
  - the child is called with `ply + 1` and `depthLeft - 1`;
  - `evalDepth` becomes `depthLeft`, which is also what the table stores;
  - `mateAtPly`, `ttValueToStore` / `ttValueFromProbe`, the killers, `bv.moves.lookup` and `maxPly`
    keep using `ply`.

  The public overload (`MinMaxSearch.hpp:123`) keeps its parameters. Its `depth` argument is the
  starting ply, 0 in every caller, and it passes `config.maxDepth` as `depthLeft`. `quiescence` already
  takes a ply.
- **A ply guard for later steps.** At `ply >= MAX_PLY` (128, the killers' bound), `alphabeta` and
  `quiescence` return the static evaluation at once, before visiting any move. Extensions (step 5) and evasions (step 4) can make a line
  longer than the iteration depth, and `MoveList` silently drops moves past 256, which would make
  `cv.moves.pop()` lose track. The guard is never reached at bench depths.
- **Test seams.** The guard is tested through the public overload's existing starting-ply argument
  (`alphabeta(node, history, table, MAX_PLY, …)`). For quiescence, `quiescenceForTest` gains a `ply`
  argument, defaulting to 0. No search to depth 132 is needed.
- **Gate.** The signature is identical at depth 6 with TT off **and** on. That holds because only the
  bookkeeping changes. Instructions are recorded.

### Step 2 — The fifty-move rule, insufficient material, and the root (rule step)

- **Insufficient material in `evaluate(board, moves)`.** Only FIDE's dead positions count, where no
  sequence of legal moves can give mate:
  - K v K;
  - K + one minor v K;
  - K and bishops v K and bishops, with every bishop on squares of one colour.

  These score 0. They are told from the bitboards (no pawn, rook or queen, then count knights and test
  bishops against the light-square mask). It is a new `static bool ChessEvaluater::isDeadPosition(const
  ChessBoard &)`, and `evaluate` returns 0 when it holds, after the mate/stalemate test. K+N+N v K,
  K+N v K+N and K+B v K+N are not dead and keep their material score.
  - **Why `evaluate`.** Every leaf passes through it: the horizon without quiescence, stand-pat and the
    no-move node. The value depends only on the position, so it is safe in the table.
- **The fifty-move rule in `alphabeta`, after the repetition check.**
  - At `ply > 0`, when `node.halfMoveClock >= 100` the node is a draw (0), unless the side to move is
    checkmated. That needs one `firstMoveOnly` generation, and only when the clock is at 100 or more and
    the side is in check.
  - Negative clocks from old FENs (I1, see speed step 5) simply reach 100 later. Clocks of `INT_MAX`
    saturate (`ChessBoard.cpp:261`) and stay at 100 or more.
  - Quiescence checks the rule too, from step 4 on, where its quiet evasions can advance the clock
    (step 4, "Draws in quiescence").
- **The root is never drawn by rule.** The repetition and fifty-move checks run at `ply > 0` only. The
  root is searched and always returns a move. Its children still score 0 when the rule applies to them
  (a quiet move at clock 99 reaches 100). The app is unaffected, because `gameEnd` keeps blocking a
  drawn position. The UCI tool always gets a `bestmove` with a move.
- **The draw counter, for step 3.** `MinMaxSearch` gains `int64_t pathDraws`. It counts the 0s returned
  by repetition or by the fifty-move rule, since `reset()`. Both depend on the path, not on the
  position. Insufficient material does not count, because it is a property of the position.
- **What does not change.** `ChessEvaluater::isDraw` stays "threefold repetition" (its name and its
  `gameEnd` caller). The fifty-move check is a separate helper, `ChessEvaluater::isFiftyMoveDraw(ChessBoard &)`,
  so that `gameEnd` never reports a fifty-move draw as `repetition`. Whether `gameEnd` and the app learn
  the two new draws is D2. Recommended: not in this plan.

### Step 3 — A transposition table fit for cut-offs (exact with TT off)

- **Draws before the probe.** The order at the top of `alphabeta` becomes:
  1. the ply guard;
  2. repetition;
  3. fifty-move;
  4. the TT probe.

  Then come the horizon and the move loop, as today.
- **Path-dependent values are not stored as values.** At node entry, `alphabeta` reads `pathDraws`.
  At the store, if `pathDraws` has changed, a 0 from repetition or the fifty-move rule was used
  somewhere below. The entry is then stored with a new `TranspositionEntryType::MOVE_ONLY`: its
  `bestMove` still orders a later search (`tableMove`), and `ttCutoff` returns `false` for it.
  - This is conservative: any subtree that met such a draw stores no value. It is also exact for move
    ordering, because `tableMove` reads only `bestMove`.
  - No new field: the type enum gains one value, and the entry stays 32 bytes (the size test from
    speed step 2 guards this).
- **Where the table never cuts off.**
  - At the root (`ply == 0`). The root is always searched, so its PV is complete and its value reflects
    the real history.
  - At PV nodes, from step 7 on (step 6 defines them).
  - When `node.halfMoveClock >= 90`. This is Stockfish's heuristic, not a safe rule.
- **What this does not fix: the known limitation.** Cut-offs from the table stay an approximation for
  draws that depend on the path, as in every engine that uses one. A value is stored without a draw
  below it, then reused on another path, and on that path the stored subtree would have met a draw:
  - **Repetition.** A descendant P that has already occurred twice on the new path is never visited,
    so its third occurrence is never seen.
  - **Fifty-move.** A node probed at clock 89 with 11 plies left can reuse a value computed at clock 0
    and miss a fifty-move draw below it. Check extensions lengthen such lines further.

  Making the reuse depend on a compatible history would mean storing a history signature per entry, or
  refusing every cut-off within reach of a reversible repetition. Both cost most of what the table
  gives, so the plan does not try.
- **How the error is bounded.**
  - The root and PV nodes never cut off, so the line that is shown and played is searched with its
    real history.
  - `pathDraws` keeps the draws that were seen from being stored as values.
  - The clock-90 guard covers the common fifty-move case.
  - What is left is an error in a non-PV subtree, and only when the PV would change, which step 7's
    SPRT measures with everything else.
  - A test, `HiddenRepetitionIsAKnownLimitation`, pins down today's behaviour so that a later change
    is deliberate.
- **Gate.** Bench signature identical with TT off: the probe is skipped, and `MOVE_ONLY` keeps the
  ordering move. With TT on, the bench is recorded.

### Step 4 — Quiescence evasions while in check (rule step)

- **At a quiescence node whose side to move is in check:**
  - No stand-pat.
  - Generate **all** legal moves with `ChessMoveGenerator::generateMoves(node)`. The generator is
    legal (`MoveList::addSingleMove`), so in check these are exactly the evasions.
  - No legal move means mate: `mateAtPly(-MAT_VALUE, ply)` from the side to move.
  - Otherwise `bestValue` starts at `-INT_MAX`, and each evasion is searched with `quiescence(ply + 1)`.
    Delta pruning (and SEE, step 12) never applies to an evasion.
  - The same sort, so captures come first.
- **Draws in quiescence.** A quiet evasion can repeat a position and advance the half-move clock. For
  example, in `k3r3/8/8/8/8/8/8/Q3K3 w - - 99 1` at the horizon every evasion is quiet and reaches
  clock 100. So:
  - `quiescence` takes the history again (`const HistoryPtr &`) and pushes and pops each move's hash,
    as `alphabeta` does. Speed's step 5 removed this because only captures were searched. Evasions
    bring it back.
  - **The fifty-move check runs at every quiescence node.** It is one integer compare on
    `halfMoveClock`, independent of `reversiblePlies`. The legal-move test it needs only runs when the
    clock is at 100 or more.
  - **The threefold check runs when the last move was reversible or the history is unknown**
    (`reversiblePlies != 0`). `reversiblePlies` is −1 after a FEN and stays −1 after quiet moves
    (`ChessBoard.cpp:380-383`), so `> 0` would skip exactly the FEN-loaded games.
    `isThreefoldRepetition` already scans the whole history when the count is −1. Only right after a
    capture or a pawn move (`reversiblePlies == 0`) can no position repeat, so the common capture node
    still pays nothing.
  - Each draw found increments `pathDraws`.
  - The cost (one push and one pop per quiescence move) is recorded on the bench.
- **Termination.** A quiet evasion can give check back, so evasions do not need a capture between
  them. A line of quiet checks and evasions ends in one of three ways:
  - a capture (material is finite);
  - a threefold, now detected in quiescence;
  - the ply guard at `MAX_PLY`.

  These lines are rare and narrow (each evasion node has few moves), and the bench records their
  cost.
- **Not in check: unchanged.** The `firstMoveOnly` mate test in stand-pat stays as it is.
- **Cost.** Recorded on the bench. Nodes are expected to rise slightly.

### Step 5 — Check extension (SPRT, non-regression; D3)

- **The rule.** When the move just played gives check, the child is searched with `depthLeft`
  unchanged (one ply of extension).
  - The extension is skipped once `ply >= 2 * config.maxDepth`, so a perpetual-check line is bounded.
  - The ply guard is the backstop.
  - The check is already computed: `newNode.isCheck(newNode.color)` is called on the board the loop
    has just built.
- **No extension in quiescence.** Step 4 handles check there.
- **Test.** `KnightEscapeAttackByPawn` keeps its depth-5 line. A new depth-4 case asserts that the first
  move is one of Stockfish's within 30 cp (Ne5, Ne7, Nb8, Qe7+). That case is red today (Nb4).
- **Gate.** Non-regression SPRT [−5, 0] against step 4's commit (D3).

### Step 6 — Principal variation search (bench-gated)

- **The rule.** At every `alphabeta` node:
  - The first move gets the full window `(−beta, −alpha)`.
  - Every later move first gets a zero window `(−alpha − 1, −alpha)`. When its score is above `alpha`
    and below `beta`, it is searched again with the full window.
  - **A PV node is an explicit `bool pvNode` parameter, never computed from the window**, so there is no
    `beta − alpha`, which overflows `int` on the root window `(−INT_MAX, INT_MAX)`. The root is a PV
    node. The first move of a PV node is searched as a PV node. Every other child is searched as a
    non-PV node, and when its score beats `alpha` at a PV node, it is searched again as a PV node with
    the full window. Steps 7–11 use this flag.
  - **The window arithmetic stays in range.** The zero window `(−alpha − 1, −alpha)` is used only
    after the first move has set `alpha` to a real score, bounded by ±`MAT_VALUE`, so it cannot wrap.
  - The PV is pushed only from a full-window result, so it stays complete.
- **Quiescence keeps its full window.** PVS buys little there.
- **Exact value.** With the root window `(−INT_MAX, INT_MAX)` and no other pruning, the root value is
  that of alpha-beta. Repetition makes the value path-dependent, but not order-dependent, which is the
  argument speed's step 6 rests on.
- **Gate.** The same score and best move on every bench position, **with TT cut-offs and delta
  pruning off**. Delta pruning depends on alpha, which the zero windows change, so with it on the
  scores could differ for a reason other than PVS. The bench gains `DELTA=0|1` (default 1) for this.
  `PvsDoesNotChangeTheScore` turns it off too. Total nodes in that configuration must drop by at
  least 5 % (re-searches included, since `visitedNodes` counts them), and instructions per
  node must not rise by more than the nodes saved. Nodes and instructions with the shipped defaults
  (delta pruning on) are recorded beside them. Otherwise the zero windows are dropped and recorded.
  The `pvNode` parameter stays either way, with the same rule (first move PV, a later move that beats
  `alpha` at a PV node searched again as PV), but every child then gets the full window. Steps 7–11
  then rely on that rule.

### Step 7 — TT cut-offs on by default (SPRT [0, 10])

- **Where the table cuts off.** Only at nodes with `pvNode == false`, never at the root, and not at
  clock 90 or above (step 3). PV nodes are still searched, so the PV the app and UCI show is the
  full line.
- **On by default.** `FEngine`'s `_ttEnabled` defaults to `YES`, so `BChessUCI` gets cut-offs. The app
  setting is D1. Recommended: remove the "Use Transposition Table (Beta)" toggle and the two
  `UserDefaults` reads in `GameSession.swift` (`:478`, `:521`), so that cut-offs are always on. A stored
  `useTranspositionTable` key is then ignored, which is harmless.
- **The bench default becomes `TT=1`,** since that is now what ships. Both are still recorded.
- **Gate.** SPRT [0, 10] against step 6's commit (or step 5's, if PVS was dropped). The base binary
  has the table off, the checkout has it on.

### Step 8 — Null-move pruning (SPRT [0, 10])

- **The null move.** `ChessBoard::moveNull()`, beside `move()`, with the same incremental hash keys:
  - the side to move flips (`getWhiteTurn`);
  - the en-passant key is taken out (`ChessBoardHash::enPassantKey`) and `enPassant` is cleared;
  - `halfMoveClock` is left unchanged: a pass is not a move, and incrementing the clock would let a
    null move followed by one quiet move reach 100 one ply early (at clock 98), whose 0 could then cut
    off when `beta <= 0`;
  - `reversiblePlies` becomes 0, so no repetition is counted across the null move.

  The null child is pushed on the history like any move, and its hash is pushed.
- **When it is tried.** After the TT probe **and after the node's moves are generated and found
  non-empty**, so a checkmate or a stalemate is scored by `evaluate(node, moves)` before any null
  move. Otherwise a stalemate with pieces left could be cut off by the null branch instead of
  returning 0. Generating first costs the generation at nodes that the null move cuts off, where today
  it would have happened anyway. It must hold at a node where all of these hold:
  - it is not a PV node;
  - the side to move is not in check;
  - `depthLeft >= 3`;
  - the previous move was not a null move (a `bool` parameter of `alphabeta`);
  - `beta` is not a mate score;
  - the side to move has a knight, bishop, rook or queen (no null move in pawn-only endings, where
    zugzwang is common).
- **The search.** `R = 2`, plus 1 when `depthLeft > 6`. The null child is searched with a zero window
  `(−beta, −beta + 1)`, at depth `depthLeft − 1 − R`, with no PV. A score of `beta` or more returns
  `beta`, never a mate score: a mate found after passing is not a real mate. The table stores nothing
  for a null-move cut-off.
- **Rule draws below a null move.** Any repetition or fifty-move draw found in the null branch still
  increments `pathDraws`, so a node whose cut-off came from such a branch stores no value.
- **Stop.** When `stopped()` is true after the null search, its score is not used (I2, below).
- **Gate.** SPRT [0, 10] against the previous step.

### Step 9 — Late-move reductions (SPRT [0, 10])

- **When a move is reduced.** At `depthLeft >= 3`, the moves from index 3 on (after the hash move,
  the captures and the killers have had their turn), when all of these hold:
  - the move is quiet: not a capture, not a promotion, not a killer;
  - it does not give check;
  - the side to move is not in check.
- **By how much.** Reduction 1, or 2 when the index is at least 8 and `depthLeft >= 6`. The values are
  fixed and not tuned in this plan.
- **The search.** A reduced move gets a zero-window search at `depthLeft − 1 − R`. If it beats
  `alpha`, it is searched again at full depth with the PVS zero window, then with the full window at a
  PV node, as in step 6. It is never reduced below quiescence (`depthLeft − 1 − R >= 1` after the
  move, otherwise no reduction).
- **Gate.** SPRT [0, 10] against the previous step.

### Step 10 — Aspiration windows (SPRT [0, 10]; optional)

- **The window.** From iteration 5 on, `IterativeDeepening::search` searches the root with
  `(previous − 50, previous + 50)`, unless the previous score is a mate score.
- **On a fail.** On a fail-low or a fail-high, that side of the window is widened to the full window
  and the iteration is searched again. A second fail opens the other side too.
- **Stop.** The re-search loop ends as soon as the search is stopped or cancelled. An interrupted
  re-search is an interrupted depth, which is not recorded (`IterativeDeepening.hpp:127-128` already
  says so).
- **A public entry point.** The public `alphabeta` gains an overload with an explicit window. The
  existing one keeps the full window.
- **Gate.** SPRT [0, 10]. Dropped and recorded otherwise.

### Step 11 — Futility pruning (SPRT [0, 10]; optional)

- **When a move is skipped.** At `depthLeft == 1`, at a non-PV node that is not in check, when neither
  alpha nor beta is a mate score, and `evaluate(node, moves) * color + FUTILITY_MARGIN <= alpha` (200 cp,
  the same as `DELTA_MARGIN`). Then quiet moves that do not give check are skipped. Captures,
  promotions, checks and the first move are still searched.
- **The static evaluation.** It uses the move list the node has already generated, so there is no
  second generation.
- **A selective approximation, not a bound.** In zugzwang the static evaluation can be above every
  legal continuation, so a skipped move proves nothing. When a move was skipped, the node returns
  `max(bestValue, staticEval)`, which is below `alpha` (a fail-low). It stores its entry as `MOVE_ONLY`,
  or nothing without a best move, so no fabricated bound reaches the table.
- **Gate.** SPRT [0, 10]. Dropped and recorded otherwise.

### Step 12 — SEE pruning in quiescence (SPRT [0, 10]; optional, D4)

- **Port the finished candidate** from speed's step 9 (`/private/tmp/claude-501/bchess-engine3/wt9`):
  - `ChessEvaluater::see`;
  - `Configuration::seePruning`;
  - `SEETests.cpp` (11 cases);
  - `MinMaxSearchTests.PruningKeepsPinnedMate`, without the bishop (see speed's Follow-ups).

  The copy predates speed's review rounds, so only those files and the pruning condition in
  `quiescence` are taken. Its two-argument `Variation::push` is not (speed review round 1 removed it).
- **The rule.** A capture with `see < 0` is skipped, except promotions, captures that give check (the
  shared exemption) and evasions (step 4).
- **Gate.** SPRT [0, 10] against the previous step. Dropped and recorded otherwise. The scratch copy
  may be gone by then. In that case the step is dropped, not rebuilt.

### Step 13 — Measurement and record

- **Whole plan.** `BASE=4986ad7 TIMEMARGIN=200 scripts/elo-match.sh`, SPRT [0, 10].
- **Stockfish.**
  - A 40-game probe at `LEVEL=2200`, then `GAMES=300` at the level the probe picks.
  - TC 10+0.1, `TIMEMARGIN=200`, as in speed.
  - One row in `docs/elo.md`, plus a sentence on what changed.
- **`docs/elo.md`.** "Caveats" is updated (the table cuts off; the fifty-move rule and quiescence in
  check now exist), and so is the method's "transposition table off" line.
- **The bench results table** in this plan is completed.

### Reuse

- **Draws.** `ChessEvaluater::isDraw` and `ChessHistory::isThreefoldRepetition` (with
  `reversiblePlies`) are unchanged. `ChessBoard::halfMoveClock` is already maintained by `applyMove`.
- **Mates.** `ChessEvaluater::evaluate(board, moves)` (mate and stalemate from an empty list),
  `isMateScore`, `matePlies`, and `MinMaxSearch::mateAtPly` / `ttValueToStore` / `ttValueFromProbe` /
  `ttCutoff`.
- **Moves and checks.** `ChessMoveGenerator::generateMoves` (legal, so in check it gives the evasions)
  and its `Mode::firstMoveOnly`. `ChessBoard::isCheck`.
- **Hash keys.** `ChessBoardHash::getWhiteTurn` and `enPassantKey`, used incrementally by `applyMove`.
  The null move uses the same keys.
- **The table and ordering.** `TranspositionTable` (generation, `MOVE_ONLY` added to the existing type
  enum), `tableMove`, `recordKiller` / `promoteKillers` / `MAX_PLY`.
- **Stop and the test hooks.** `MinMaxSearch::stopped()`, the `IterativeDeepening` status and
  `completedDepth`, the `BCHESS_TEST_HOOKS` `checkpoint` and `quiescenceForTest`.
- **Tools.** `scripts/bench.sh` (signature, `--compare`), `scripts/elo-match.sh` A/B mode with
  `ELO0`/`ELO1`/`TIMEMARGIN`/`MAX_GAMES`, and the method in `docs/elo.md`.
- **SEE.** The wt9 candidate (step 12).

## Alternatives rejected

- **Storing every value, as most engines do,** with the draw checks before the probe. It is simpler,
  but it keeps the bug ENGINE-1 named: a repetition 0 that was seen being reused on another path. A
  per-subtree counter is one integer and a compare, and the entry still serves ordering. The opposite
  direction (a draw hidden by a probe) is accepted as a limitation (step 3).
- **Table entries that carry a history signature,** or no cut-off within reach of a reversible
  repetition. This would make reuse exact, but it costs most of what the table gives (Codex round 1
  asked for this or an honest limitation; the plan takes the limitation).
- **Twofold repetition in the search** (a position repeated once on the search path scores 0). It is
  common, and it finds draws sooner, but it changes what `isDraw` means for `gameEnd`. It is left for
  later, and only if an SPRT asks for it.
- **The fifty-move rule inside `isDraw`.** `gameEnd` calls `isDraw` and would report `repetition` for
  a fifty-move draw.
- **Insufficient material as an early return in `alphabeta`.** It saves a few nodes in dead endings,
  but only `evaluate` sees every leaf, quiescence's included.
- **TT cut-offs at PV nodes.** These truncate the PV that the app and UCI show, and they are where
  graph-history errors cost the most. PVS (step 6) makes most nodes non-PV, so little is lost.
- **TT cut-offs before PVS.** Under plain alpha-beta, almost every node has a wide window, so a
  "non-PV only" rule would leave almost no cut-offs. Cutting off at every node would truncate PVs. That
  is why step 6 comes before step 7.
- **An SPRT for every step.** Steps 1, 3 and 6 cannot change the root value at a fixed depth, so the
  bench proves them. Steps 2 and 4 are rule fixes (Jean: no SPRT). The whole-plan SPRT covers them all.
- **Tuning R, the LMR table or the margins.** That is a different job, done with many SPRTs. Fixed,
  common values are used.
- **Internal iterative deepening, singular extensions, a history heuristic.** The history heuristic
  was measured and dropped in speed's step 7b. The other two do not pay at this depth.

## Test plan

Every engine test is a GoogleTest case. "Red" means it fails before its step and is proven so in the
step's commit message.

| Step | Test | Proves | Red before? |
|---|---|---|---|
| 1 | Existing `MinMaxSearch.*`, `SearchChess.*` (exact counts unchanged), `BestMove.*`, `IterativeDeepening.*`; bench signature identical TT off and on | The split is bookkeeping | guards |
| 1 | `MinMaxSearchTests.PlyGuardStopsAtMaxPly`: the public overload with starting ply `MAX_PLY` and `maxDepth` 3 on Kiwipete → `visitedNodes == 0` and the score equals the static evaluation; the same at starting ply `MAX_PLY − 1` visits moves. `quiescenceForTest(…, ply = MAX_PLY)` on a position with captures → no node visited, static score | The guard runs at the boundary and nowhere else | yes; and red again with the guard deleted in a scratch copy (proof in the commit) |
| 2 | `EvaluationTests.DeadPositionsScoreZero`: K v K, K+N v K, K+B v K, K+B v K+B on same-coloured squares → 0 from both sides | FIDE dead positions | yes |
| 2 | `EvaluationTests.LiveMaterialKeepsItsScore`: K+B v K+B on opposite colours, K+N+N v K, K+N v K+N, K+B v K+N, K+P v K → `isDeadPosition` is false, and `evaluate` equals its value before step 2 (recorded in the test) | Only dead positions change | no (guard) |
| 2 | `MinMaxSearchTests.FiftyMoveRuleDrawsAWin`: K+Q v K, White to move, clock 99, no mate in 1 → every quiet move reaches 100, score 0 at depth 2. The same FEN at clock 0 → a large positive score | The rule, from the clock | yes |
| 2 | `MinMaxSearchTests.MateOnTheHundredthPlyIsMate`: clock 99, a quiet non-pawn mate in 1 → `MAT_VALUE − 1` | Mate takes precedence | no (guard; red if the rule ignored mate) |
| 2 | `MinMaxSearchTests.DrawnRootStillReturnsAMove`: (a) a FEN at clock 100 and (b) a threefold built through `ChessGame::move` (`g1f3 g8f6 f3g1 f6g8` twice) → `IterativeDeepening::search` at depth 3 returns a legal first move | The root is never drawn by rule (I4) | (b) yes, (a) yes after the rule |
| 2 | Existing `ChessGameTests.Repetition*`, `GameSessionTests` repetition, `FEngineTests.gameEndCrossesTheBridge` | `gameEnd` unchanged | guards |
| 3 | `MinMaxSearchTests.RepetitionBeatsTableEntry`: history in which the child after `f6g8` is a third occurrence; the table preloaded with an `EXACT` +500 entry for that child at depth 10; depth 2, TT on → that child scores 0 (the root's score equals a fresh-table search) | Draws before the probe | yes |
| 3 | `MinMaxSearchTests.PathDrawIsNotStoredAsValue`: the same search; then the table entry for the parent of the repeated position has type `MOVE_ONLY` (or no entry); a second search of that parent with a fresh one-entry history and the same table returns the same score as with a fresh table | No path-dependent value is reused | yes |
| 3 | `MinMaxSearchTests.NoCutoffAtRoot`: preload an `EXACT` entry for the root at depth 10 with a bogus value; depth 2 search → the root's score is the searched one and the PV has more than one move | Complete root PV | yes |
| 3 | `MinMaxSearchTests.NoCutoffNearFiftyMoves`: a position at clock 95, preloaded `EXACT` entry → ignored; the same at clock 10 → used | The 90 guard | yes |
| 3 | `MinMaxSearchTests.HiddenRepetitionIsAKnownLimitation`: a position N whose entry was stored by a search with a one-entry history, then searched again at a non-PV ply where a descendant P already occurred twice on the history → the table's value is used (P's draw is not seen). The same node at a PV ply (or with TT off) → the draw is seen. Documents the limitation of step 3; a change to it must update this test deliberately | The known limitation is pinned down, and PV nodes are exempt | n/a (documents it; written in step 3 with the TT-off half, the PV half added in step 7) |
| 3 | `TTMateIsPlyRelative` case (b) is rewritten so that the reading probe is at a non-root ply other than the storing one (the root no longer probes) | Keeps covering the conversion | n/a (adjusted) |
| 4 | `MinMaxSearchTests.QuiescenceDoesNotStandPatInCheck`: through `quiescenceForTest`, a position whose side to move is in check by a knight that also attacks its queen (the implementer builds the FEN and confirms with Stockfish) → the score is at least a queen-minus-knight below the stand-pat | Evasions searched | yes |
| 4 | `MinMaxSearchTests.QuiescenceSeesFiftyMoveDraw`: `k3r3/8/8/8/8/8/8/Q3K3 w - - 99 1` through `quiescenceForTest` loaded from the FEN, so `reversiblePlies == -1` → 0 (every evasion is quiet and reaches clock 100), and `pathDraws` grew | Rule draws inside quiescence | yes |
| 4 | `MinMaxSearchTests.QuiescenceSeesRepetition`: a history where a quiet evasion at the horizon makes a third occurrence → that evasion scores 0, both for a game played from the start (`reversiblePlies >= 0`) and for one loaded from a FEN (`reversiblePlies == -1`) | Repetition inside quiescence | yes |
| 4 | `MinMaxSearchTests.QuiescenceMateInCheck`: a horizon position in check with no evasion → `−(MAT_VALUE − ply)` | Mate in quiescence with check | no (guard) |
| 4 | Existing delta-pruning tests, `QuiescenceReturnsTheBestCapture`, `QuiescenceNeverBelowStandPat` | Not-in-check path unchanged | guards |
| 5 | `BestMoveTests.KnightEscapeAttackByPawnDepth4`: depth 4 → first move in {Nc6e5, Nc6e7, Nc6b8, Qd8e7} | The ENGINE-1 horizon case | yes (Nb4 today) |
| 5 | `MinMaxSearchTests.PerpetualCheckIsBounded`: a perpetual-check position, depth 6. A `BCHESS_TEST_HOOKS` counter, `maxSearchPly`, holds the deepest `alphabeta` ply (not quiescence) → `maxSearchPly <= 2 * 6`, and at least one extension was refused by the bound (a second hook counter) | The extension bound itself, not the ply guard or quiescence | yes, with only the `2 * maxDepth` bound removed in a scratch copy (`maxSearchPly` then goes past 12) |
| 6 | `MinMaxSearchTests.PvsDoesNotChangeTheScore`: PVS on/off, TT and every pruning off, depths 1–3 on the `SortingDoesNotChangeTheScore` positions plus Kiwipete → same score | Exactness | no (guard) |
| 6 | `MinMaxSearchTests.RootWindowIsSafe`: a root searched with `(−INT_MAX, INT_MAX)` gives the same score with PVS on and off; the standalone bench is built once with `-fsanitize=undefined` and runs at depth 5 with no report (recorded in the commit) | No window arithmetic overflow | n/a (guard) |
| 6 | `IterativeDeepeningTests.PrincipalVariationReplaysLegally`: default config, depth 5, three positions → every PV move is in `generateMoves` of the position it is played from, and the PV is at least `depth` long unless it ends in mate or a draw | PV integrity under PVS (and, rerun at step 7–11, under pruning) | no (guard) |
| 7 | `FEngineTests.TableCutsOffByDefault` (Swift): a fresh `FEngine` has `ttEnabled == true`; bench default `TT=1` | Default on | yes |
| 7 | `MinMaxSearchTests.NoCutoffAtPVNode`: a preloaded bogus `EXACT` entry for a position reached at ply 1 along the PV → the PV continues past it | PV integrity | yes |
| 7 | Existing `MateCarriesDistance`, `PrefersShorterMate`, `TTMateIsPlyRelative` with TT on | Mates unchanged | guards |
| 8 | `BoardHashTests.NullMoveHash`: for Kiwipete, position 3 (with en passant) and a FEN with an en-passant square → `moveNull()` hash equals `ChessBoardHash::hash` from scratch; `enPassant == 0`; colour flipped; `reversiblePlies == 0`; `halfMoveClock` unchanged | The null move keeps the hash exact | yes |
| 8 | `MinMaxSearchTests.NullMoveDoesNotAdvanceTheClock`: a non-PV node at clock 98 with `beta <= 0` where, with the clock incremented by the null move, the null branch would return a fifty-move 0 and cut off (the implementer builds the position) → no null cut-off | Synthetic branches cannot fake a rule draw | yes, with the increment restored in a scratch copy |
| 8 | `MinMaxSearchTests.NullMoveSkippedInPawnEnding`: a pawn-ending zugzwang (implementer builds it, confirms with Stockfish) → the winning move at depth N with null move on; red with the pawn-only guard deleted in a scratch copy | Zugzwang guard | yes (scratch) |
| 8 | `MinMaxSearchTests.MatesSurvivePruning`: the mate-in-1/2/3 positions of `MateCarriesDistance` through `IterativeDeepening` with every default on → exact mate distance | Mate scores under pruning | no (guard) |
| 8 | `MinMaxSearchTests.NullMoveKeepsStalemate`: a non-PV node (reached through a zero-window search) in a stalemate where the side to move still has a rook, null move on, depth ≥ 3 → 0. Also the root of a depth-4 search whose only non-losing line walks into that stalemate → 0 | Terminal detection precedes the null move | yes, with the null move moved before generation in a scratch copy |
| 9 | `MinMaxSearchTests.LmrKeepsQuietMate`: a mate in 2 whose first move is a quiet move sorted late (index ≥ 8) → found at depth 4 with distance `MAT_VALUE − 3` | Re-search after a reduced fail-high | no (guard; red with the re-search deleted in a scratch copy) |
| 10 | `IterativeDeepeningTests.AspirationMatchesFullWindow`: TT and pruning off, a position whose score jumps between depths 4 and 5 (a tactic) → the same score as a full-window search; `IterativeDeepeningTests.StopDuringAspirationResearch`: `checkpoint` stops the search inside a re-search → the search returns, no callback for that depth, the previous depth's line is kept | Aspiration exact and stoppable (I2) | the second is red with the stop check deleted (scratch) |
| 11 | `MinMaxSearchTests.FutilityKeepsQuietCheckmate`: depth-1 node, eval far below alpha, a quiet mating move → still found | Checks exempt | yes with the exemption deleted (scratch) |
| 11 | `MinMaxSearchTests.FutilityStoresNoBound`: a depth-1 node where futility skipped a move → its table entry is `MOVE_ONLY` (or absent) | No fabricated bound in the table | yes |
| 12 | `SEETests` (ported) and `PruningKeepsPinnedMate` | As in speed's step 9 | as recorded there |
| every step that adds GoogleTests | `EngineGoogleTests.registersAllCases` floor (today `>= 183`) raised to the new total | Registration | n/a |
| all | `SearchChessTests` counts updated with old/new in the commit; changed best-move tests by the ENGINE-1 Stockfish rule | | |

New search tests use depth ≤ 5 (milliseconds in the Debug bundle). The bench and the matches are
developer tools, not CI.

## Invariants

- **I1 (files keep opening).** Not applicable. No file format or parser changes. An old FEN with a
  negative or huge half-move clock still loads. The search applies the rule from the clock as it is,
  and `gameEnd` is unchanged (D2).
- **I2 (a result lands only on its position).** Holds.
  - The bridge's generation check (`FEngine.mm:350-380`) is untouched.
  - Inside the engine, the risk is a partial value acted on. A null-move search, an LMR or PVS
    re-search, or an aspiration re-search that was cut short returns a meaningless score. The rule is
    the one that already guards the store (`MinMaxSearch.hpp:341`): after any child search, when
    `stopped()` is true, the node returns at once. It records no killer and makes no cut-off decision
    from that score.
  - `IterativeDeepening` already discards an interrupted depth, and the aspiration loop exits on stop.
  - Covered by `StopDuringAspirationResearch`, the existing `CancelledLoopStoresNoEntry`,
    `NoCallbackForInterruptedDepth` and `FEngineConcurrencyTests`.
- **I3 (portable engine).** Holds. `moveNull`, `isDeadPosition`, `isFiftyMoveDraw` and the search
  changes are plain C++. The bench's standalone build checks it.
- **I4 (UCI keeps working).** Holds, and is improved.
  - There is no protocol change and no option (D2 of speed stands; a `Hash` option is still not
    needed).
  - `bestmove` always carries a move, even at a root that is drawn by rule (step 2).
  - `info depth` stays the iteration depth, and `seldepth` grows with extensions.
  - `score mate N` still comes from `matePlies`, guarded by `MatesSurvivePruning`.
  - The callbacks still run on the search queue.
- **I5 (private and offline).** Holds.

## Risks and rollout

- **SPRT machine time.** At 5+0.05 with a concurrency of 4, about 900 games an hour.
  - A step worth +30 Elo or more (expected for TT cut-offs, null move and LMR) decides in a few hundred
    games, under an hour.
  - A marginal step (check extension, aspiration, futility, SEE) can run to `MAX_GAMES`: 8,000 games is
    about 9 hours. Proposed: `MAX_GAMES=8000` for steps 5, 7, 8 and 9, and `MAX_GAMES=4000` (about
    4.5 hours) for the optional steps 10–12. An inconclusive optional step is dropped.
  - Total: about 8 SPRTs plus the Stockfish runs, likely 8–12 hours and at worst about 25.
- **How the runs are scheduled (D3).** An SPRT saturates the four performance cores, and UI tests time
  out under that load. So:
  - one SPRT at a time, and never at the same time as an `xcodebuild test` gate or another project's
    heavy job;
  - each step's gates run green **before** its SPRT starts, and the SPRT tests that commit;
  - the implementer may write the next step's code while an SPRT runs, but runs no gate and no bench
    until it ends;
  - every run uses `TIMEMARGIN=200`, as speed's later runs did;
  - long runs (the optional steps, and any step that passes 2,000 games) are best started in the
    evening, and the run logs stay in `.elo/runs`.
- **A failed step is dropped, not forced.** The later steps are rebased onto the last landed commit. If
  PVS's zero windows (step 6) are dropped, the `pvNode` parameter and its rule stay (step 6, Gate), and
  steps 7–11 use it unchanged.
- **Node-count tests.** `SearchChessTests` counts change at steps 4–12, and are updated with old and
  new values in each commit. The scores stay, except where a rule step changes them by design.
- **iOS.** It uses the same 16 MB table, now with cut-offs. That needs no extra memory. The pending
  speed device check (memory gauge) covers it.

## Decisions left open for Jean

**Decision (Jean, 2026-10-07):** D1 TT cut-offs always on (the "Use Transposition Table (Beta)" toggle and its reads are removed; `FEngine` defaults on). D2 search only (`gameEnd`, bridge and UI unchanged). D3 gates as recommended: [0, 10] for steps 7–12, [−5, 0] for check extension, one SPRT at a time, never during an `xcodebuild` gate, long runs in the evening. D4 SEE stays as optional step 12 (port from wt9).

- **D1 — TT cut-offs in the app.** **Recommended:** always on, the "Use Transposition Table (Beta)"
  toggle and its two reads are removed, and `FEngine` defaults to on. That is one behaviour, which the
  SPRT measured. Alternative: keep the toggle, with its default flipped to on.
- **D2 — The new draws in `gameEnd`.** **Recommended:** search only. The engine scores the positions
  as draws, and the app keeps today's game-end rules (checkmate, stalemate, threefold), so no bridge,
  text or UI change is needed. Alternative: `gameEnd` also reports `fiftyMove` and
  `insufficientMaterial`, which blocks play there as repetition does. That needs a bridge enum case,
  `GameText` strings and Swift tests. FIDE makes dead positions automatic but the fifty-move rule a
  claim (75 moves automatic).
- **D3 — The strength gates and their schedule.** **Recommended:**
  - SPRT [0, 10] for steps 7–12;
  - non-regression [−5, 0] for check extension (step 5), since it fixes a known horizon blunder;
  - `MAX_GAMES` 8,000 for the core steps and 4,000 for the optional ones;
  - one SPRT at a time, never during an `xcodebuild` gate, with long runs started in the evening.

  Alternative: [−5, 0] for every step, as Jean chose for speed's steps 8–9. It accepts faster but
  does not show a gain.
- **D4 — SEE pruning.** **Recommended:** keep it as the optional step 12, porting the finished wt9
  candidate. Only an SPRT is new work, and with null move and LMR in place, quiescence is a larger
  share of the nodes. Alternative: drop it from ENGINE-3 for good.

## Results (filled in by the implementer)

Bench: `scripts/bench.sh`, depth 6, Apple M2. The baseline was measured for this plan (one run).
Instructions are the speed metric.

| Step | Commit | TT | Nodes / signature | Instructions | SPRT | Landed? |
|---|---|---|---|---:|---|---|
| baseline | 4986ad7 | off | 2,214,483 / 738f8a9f29c38a0d | 11,794,137,138 | — | — |
| baseline | 4986ad7 | on | 1,680,703 / da333c334f93cd8f | 7,749,765,139 | — | — |

## Review round 1 (Codex) — how each finding was handled

1. **Blocker: TT cut-offs are not history-safe** (a probe hides a draw below it). Accepted as a
   limitation, not fixed. Step 3 no longer claims safety. It states the limitation and how it is
   bounded: no cut-off at the root or at PV nodes, `pathDraws`, and the clock-90 heuristic. It keeps a
   regression test, `HiddenRepetitionIsAKnownLimitation`. Making reuse exact (a history signature
   per entry) is a rejected alternative, because it costs most of the table's gain. Step 7's SPRT
   judges the net effect.
2. **Blocker: the clock-90 guard is insufficient.** Accepted. It is now called a heuristic
   (Stockfish's), and the case of clock 89 with 11 plies left is named as part of the known
   limitation.
3. **Blocker: draws inside quiescence.** Accepted.
   - Quiescence takes the history again and checks threefold and fifty-move at nodes reached by a
     reversible move. The draws it finds count in `pathDraws`.
   - The termination argument is rewritten: quiet counter-checks exist, so lines end by a capture,
     by repetition or by the ply guard.
   - Two new tests, one of them using the review's FEN.
4. **Blocker: `beta − alpha` overflows.** Accepted. PV-ness is an explicit `bool pvNode` parameter,
   and the zero window is formed only after `alpha` holds a real score. `RootWindowIsSafe` is added.
5. **Null-move rule draws.** Accepted. `moveNull` leaves `halfMoveClock` unchanged, null-branch draws
   count in `pathDraws`, and `NullMoveDoesNotAdvanceTheClock` is added.
6. **Futility is not a sound bound.** Accepted. It is described as a selective approximation, the node
   returns a fail-low, and it stores `MOVE_ONLY`. `FutilityStoresNoBound` is added.
7. **The ply-guard test may not exercise the guard.** Accepted. It asserts no node is visited at
   `MAX_PLY` while nodes are visited at `MAX_PLY − 1`, and it carries a red proof with the guard
   deleted.
8. **The PVS-dropped fallback needs an explicit PV parameter.** Accepted. The same `pvNode` rule
   applies whether or not the zero windows land (step 6, Gate).
9. **Simpler: test the guard through the starting-ply argument.** Accepted. That is the public
   overload's existing ply argument, plus a `ply` argument on `quiescenceForTest`.

## Review round 2 (Codex) — how each finding was handled

Each claim was checked against the code before it was accepted.

1. **Blocker: quiescence skips draws on FEN-loaded histories.** Confirmed. `applyMove` sets
   `reversiblePlies` to 0 after a pawn move or capture and increments it only when it is already
   `>= 0` (`ChessBoard.cpp:380-383`), so after a FEN it stays −1, and `> 0` would have skipped the
   plan's own test position. Accepted:
   - the fifty-move check now runs at every quiescence node (a clock compare);
   - the repetition check runs when `reversiblePlies != 0`;
   - both quiescence draw tests now cover a FEN-loaded game.
2. **The null move before terminal detection.** Confirmed. In r2 the null move came after the probe,
   and the moves are generated after it (`MinMaxSearch.hpp:260`). Accepted: the null move is tried only
   after the moves are generated and found non-empty. `NullMoveKeepsStalemate` is added.
3. **The PVS exactness gate leaves delta pruning on.** Confirmed: `Configuration::deltaPruning`
   defaults to `true` (`MinMaxSearch.hpp:38`), and its rule reads `alpha`
   (`MinMaxSearch.hpp:395-397`). Accepted: the gate and `PvsDoesNotChangeTheScore` run with delta
   pruning off (bench `DELTA=0`), and the shipped configuration is measured beside them.
4. **`LiveMaterialKeepsItsScore` can be wrong for a live position that evaluates to 0.** Accepted:
   it asserts `isDeadPosition == false` and the unchanged evaluation.
5. **The extension-bound test does not isolate the bound.** Accepted: it reads the deepest
   alpha-beta ply and counts refused extensions through test hooks. It is proven red with only the
   bound removed.
