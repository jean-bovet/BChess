# ENGINE-1 — Engine bug fixes, proven by perft

Revision 4 (2026-10-06): Jean's decisions recorded (Stockfish judge, I1 narrowed in `AGENTS.md`,
minimal SAN, scope as planned, go). Codex plan round 2 folded in: its blocker and its legacy-hash
item concerned option (a) of the I1 decision, which Jean did not pick, so both are moot; its en
passant item is accepted (two-candidate and Black-to-move cases, hash inclusion and exclusion
against python-chess, incremental == `ChessBoardHash::hash` after the capture). Last revision
before implementation.
Revision 3 (2026-10-06): Codex plan round 1 folded in. I1 exposure (saved games with a castle B1
allowed) is now an open decision with two specified options instead of a default; en passant enters
the hash only when the capture is legal (pinned and rank-exposure cases tested against FIDE
expectations); the promotion piece must be an explicit Q/R/B/N; NAGs, comments and variations are
consumed in any order; the quiescence test now separates best from last and from stand-pat, PV
included; step 7 uses `board.reset(); board.clear();`. Mate distance left the follow-ups (ENGINE-2
owns it).
Revision 2 (2026-10-06): performance-review input folded into the test plan (every depth of each
perft position, a second captured-rook case on h1, a move-ordering consistency test for B3); its
deeper hash walk and a Release-only deep perft rejected with measurements; follow-ups renamed
ENGINE-3 (ENGINE-2 is the UCI plan) and the performance findings added there. Not yet reviewed.
Revision 1 (2026-10-06): first draft.

Jean's request: "Fix all these engine bugs with perft tests." Six bugs from a code review, plus the
risks it raised. Every bug below was re-checked against the code on `main` (6da9f7f) and reproduced
with the standalone harnesses in [assets/ENGINE-1](assets/ENGINE-1/) or a scratch program linked
against the unmodified `Shared/Engine` sources.

## Problem, with evidence

**B1 — Castling rights survive the capture of a rook on its home square.**
`ChessBoard::move` clears a right only when the king moves (`ChessBoard.cpp:245-269`) or when a
*rook* leaves a1/h1/a8/h8 (`ChessBoard.cpp:318-332`); the capture block (`ChessBoard.cpp:334-343`)
never touches the rights. The generator trusts the rights and never checks that a rook stands on
the corner (`ChessMoveGenerator.cpp:272-302`), and `move()` then moves a rook that is not there
(`ChessBoard.cpp:249-267` → `ChessBoard::move(Color, Piece, Square, Square)` at `:391-402` sets a
rook on f1/d1/f8/d8 out of nothing). Perft, measured on `main`:

| Position | Depth | `main` | Reference | Failing path |
|---|---|---|---|---|
| Kiwipete `r3k2r/p1ppqpb1/bn2pnp1/3PN3/1p2P3/2N2Q1p/PPPBBPPP/R3K2R w KQkq - 0 1` | 4 | 4085659 | 4085603 | e5f7 a8d8 f7h8 → engine keeps `k`, generates e8g8 |
| Position 5 `rnbq1k1r/pp1Pbppp/2p5/8/2B5/8/PPP1NnPP/RNBQK2R w KQ - 1 8` | 3 | 62416 | 62379 | c4f7 f2h1 → engine keeps `K`, e1g1 conjures a rook on f1 |

All other counts match (start d5 4865609, position 3 d5 674624, position 4 d4 422333, position 6
d4 3894594). With the right cleared when `from` **or** `to` is a corner, all six positions match at
their deepest depth (verified in a scratch copy: Kiwipete d4 4085603, position 5 d4 2103487).

**B2 — En passant corrupts the Zobrist hash.** `createEnPassant` builds a capture of a `PAWN`
(`Move.hpp:127-131`). `move()` removes the captured pawn correctly (`ChessBoard.cpp:288-302`, hash
at `:301`), then the generic capture block XORs a pawn on the *empty* target square as well
(`ChessBoard.cpp:339-342`). Repro `4k3/8/8/3pP3/8/8/8/4K3 w - d6 0 1`, exd6: incremental
`900280ca3063d04c` ≠ from scratch `3e2556e38ab8cb21`. A perft walk comparing the incremental hash
with `ChessBoardHash::hash` at every node finds 97 bad nodes in Kiwipete d3, 153 in position 3 d4,
37 in position 5 d3. The ep square is also read with `lsb(enPassant)` (`ChessBoard.cpp:290`) rather
than from the move, which B6 can corrupt.

**R1 — The hash ignores castling rights and en passant.** `ChessBoardHash::hash`
(`ChessBoardHash.cpp:65-81`) hashes pieces and side to move only. The transposition table keys on it
(`MinMaxSearch.hpp:116-122`, `:244`), so positions that differ only in rights share an entry, and
threefold repetition (`GameHistory.cpp:12-23` via `ChessEvaluater.cpp:136-138`) counts them as the
same position, which FIDE 9.2 says they are not. Repro: `1. Nf3 Nf6 2. Rg1 Rg8 3. Rh1 Rh8 4. Ng1
Ng8 5. Nf3 Nf6 6. Ng1 Ng8` — the start arrangement occurs three times, but only twice with the same
rights (python-chess: no repetition); `main` declares it drawn. Fixed together with B2 because
both live in the hash.

**B3 — Quiescence returns the last move's score, not the best.** `MinMaxSearch.hpp:286-312`
assigns `score` in the loop and returns it, so a bad last capture overrides a good earlier one or
the stand-pat. Repro `k7/8/3p4/2p1q3/3Q4/8/8/K7 w - - 0 1`: quiescence (`alphabeta` with
`maxDepth = 0`) returns −220 while the stand-pat is −200. `alphabeta` itself is fail-soft (returns
`bestValue`, `MinMaxSearch.hpp:179-251`).

**B4 — The bishop pair uses `color` (0/1) instead of `colorSign`** (`ChessEvaluater.cpp:180-182`):
White's pair is worth 0, Black's pair +50 *for White*. Measured: the start position evaluates to
+50; `4k3/8/8/8/8/8/8/2B1KB2 w` evaluates 640 while its colour mirror evaluates −590 (must be
−640).

**B5 — The engine cannot read its own PGN.** The writer emits the check mark after the promotion
(`FPGN.cpp:871-883`, e.g. `b8=Q+`), but `parseMove` reads `+`/`#` *before* `=Q`
(`FPGN.cpp:482-494`), so `b8=Q+` fails ("Invalid SAN representation"). A rank qualifier with a
capture (`R1xe2`) has no branch (`FPGN.cpp:414-480`), NAGs (`$1`) are not skipped where comments are
(`FPGN.cpp:596-597`, `:644-645`), and an annotation after a check (`Qh5+!`) fails because the
annotation is only tried when there is no check mark (`FPGN.cpp:483-487`). All four reproduced.
Malformed input aborts in Debug instead of failing: `assert(isMoveForBlack)` (`FPGN.cpp:629`, input
`1. e4 2. d4`) and the tag asserts (`FPGN.cpp:694`, `:698`, input `[Event]`). (The asserts at
`:497-498` are unreachable: every branch above sets the square.) The writer never uses rank-only
disambiguation: it falls back to the full square (`FPGN.cpp:801-821`), writing `Re1xe2` where SAN
is `R1xe2`.

**B6 — `FFEN::setFEN` keeps state from the previous position.** It calls `board.clear()`
(`FFEN.cpp:166`), which resets only the pieces and the hash (`ChessBoard.cpp:188-192`); side
fields are set only when present (`FFEN.cpp:192-215`), and `:203` ORs the new ep square into the old
one. Repro: after `…w - d6 0 1`, setting `4k3/8/8/8/8/8/8/4K3 b` yields
`4k3/8/8/8/8/8/8/4K3 b KQ e3 5 9`. `ChessGame::setFEN` (`ChessGame.cpp:33-43`) and `replayMoves`
(`ChessGame.cpp:197-199`) reset the board first, so the app path is safe; `FFEN::setFEN` on a reused
board (tests, `FPGN::getGame` at `FPGN.cpp:998-999` uses a fresh board) is not. Related: a FEN that
claims a right whose king or rook is not on its square (`4k3/8/8/8/8/8/8/4K3 w KQkq`) makes the
generator offer a castle that conjures a rook, the same failure as B1 through input.

**Nits.** `Move.hpp:18-19` swaps origin and destination (`MOVE_FROM` is bits 0-5, `Move.hpp:92-95`).
`ChessBoard::undo_move` (`ChessBoard.cpp:350-352`) moves the piece back and nothing else (no
capture, castling, promotion, rights, hash); its only caller is `BoardHashTests.cpp:37`, which
asserts nothing after it.

## Design

The smallest change per bug, each in the existing function. One commit per step; every step is
test-first (the new test is run red on the unfixed code, then the fix, then green), as `/develop`
requires.

### Step 1 — Perft suite and the castling-rights fix (B1)

- New `BChessTests/PerftTests.cpp` (picked up by the `BChessTests` source path in `project.yml:112-115`;
  run `xcodegen generate` and commit the project). A `static uint64_t perft(ChessBoard &board, int
  depth)` built on `ChessMoveGenerator::generateMoves` (legal moves) and `ChessBoard::move`, the same
  loop as `assets/ENGINE-1/perft.cpp`; leaf count = `moves.count` at depth 1.
- Fix in `ChessBoard::move`: replace the rook-only block (`ChessBoard.cpp:318-332`) with four lines
  that clear a right when `from` or `to` is its rook corner (a1→Q, h1→K, a8→q, h8→k). This covers a
  rook leaving, a rook being captured, and anything else touching the corner. The king block stays.
- Add `assert(bb_test(pieces[moveColor][ROOK], <corner>))` before each castling rook move
  (`ChessBoard.cpp:249-267`), so a regression that conjures a rook aborts the Debug perft instead of
  silently miscounting.
- Per decision 2, this commit also narrows I1 in `AGENTS.md` (wording under "Decisions").

### Step 2 — En passant hash (B2)

In `ChessBoard::move`: compute the removed pawn's square from the move (`MOVE_TO(move) ∓ 8`) instead
of `lsb(enPassant)`, and skip the capture block's `bb_clear`/hash XOR when `MOVE_IS_ENPASSANT(move)`
(the half-move reset stays). The move keeps its capture flag: SAN (`exd6`), move ordering and
quiescence rely on it.

### Step 3 — Castling rights and en passant in the hash (R1)

- `ChessBoardHash`: four castling keys and eight en-passant file keys, drawn from the same PRNG after
  `side` (`ChessBoardHash.cpp:55-63`), and one new function `static uint64_t stateKey(const ChessBoard
  &board)` = XOR of the keys of the rights held, plus the ep file key **only when an en-passant
  capture is legal**. Its second caller is `ChessBoard::move`. The legality check runs only when a
  pawn of the side to move attacks the ep square (`PawnAttacks[INVERSE(color)][epSquare] &
  pieces[color][PAWN]`, the trick `isAttacked` uses at `ChessBoard.cpp:494`), which is rare: for each
  such pawn (at most two), on a copy of the board, clear the capturing pawn, set it on the ep square,
  clear the captured pawn, mark the occupancy dirty and ask `isCheck(color)`. If any capture leaves
  the king safe, the ep key is in. Done with direct bitboard edits, not `move()` or the generator,
  so the check cannot recurse into `stateKey`. This covers a pinned capturing pawn, a file opened by
  the captured pawn, and the rank-5/rank-4 exposure when both pawns leave the rank.
- `hash()` XORs `stateKey(board)` in. `ChessBoard::move` XORs `stateKey(*this)` out right after the
  existing `getHash()` (`ChessBoard.cpp:229`) and back in after the side switch (`:346-347`), so
  every change to rights or ep in between is covered without touching each assignment.
- Hashing ep only when the capture is legal is exactly FIDE 9.2.3: two positions are the same when
  the same moves are possible, so an ep square no legal move can use does not count.
- Prototyped in a scratch copy: the perft walk finds 0 bad nodes in Kiwipete d3, position 3 d4 and
  position 5 d3; the B2 repro hashes equal. Hashes are not persisted anywhere (only
  `ChessGame::history`, rebuilt on load, `ChessGame.cpp:197-209`; `FEngine.mm:335` copies it in
  memory), so changing their values has no file impact.

### Step 4 — Quiescence returns the best score, fail-soft (B3)

In `quiescence` (`MinMaxSearch.hpp:261-313`): keep `int bestValue = stand_pat`, raise it when a
child scores higher, return `bestValue`. Same convention as `alphabeta` (fail-soft: the returned
value may lie outside the window, never below the stand-pat). PV update and beta cut-off unchanged.

### Step 5 — Bishop pair sign (B4)

`ChessEvaluater.cpp:181`: `value += colorSign * (PieceValue[PAWN]/2);`.

### Step 6 — PGN: read what the engine writes (B5)

- `parseMove` (`FPGN.cpp:400-517`): new branch for rank + `x` + square (`R1xe2`) next to the `R6e4`
  branch; after the squares, parse in SAN order: optional `=Piece`, then optional `+`/`#`, then
  optional annotation (`!`, `?`, `!!`, `??`, `!?`, `?!`). After `=` the next character must be one of
  `Q`, `R`, `B`, `N` and is consumed explicitly; anything else (nothing, `K`, `P`, another letter) is
  a parse failure. `parsePiece` is not used there: it always returns true and maps any unknown
  character to `PAWN` (`FPGN.cpp:306-346`).
- `parseMoveText`: a `parseNAG()` (`$` followed by digits) beside `parseComment`. Before
  `game.move`, consume comments and NAGs in any order (`FPGN.cpp:597`, `:645`, the comment text
  still goes to the move). After `game.move`, consume variations, NAGs and comments in any order
  (`FPGN.cpp:608`, `:649`), so `1. e4 (1. d4 d5) $1 e5 *` and `1. e4 (1. d4) {c} e5 *` parse.
  A comment that follows a variation has no node to attach to without a new `ChessGame` API, so it
  is consumed and not kept; such input failed to open before, so nothing that opened loses text.
- Replace the reachable asserts with `RETURN_FAILURE`: `FPGN.cpp:629` and the two in `parseTag`
  (`:694`, `:698`).
- Writer (`getPGN`, `FPGN.cpp:801-821`): standard SAN order — file if it disambiguates, else rank,
  else the full square. Adds `SANType::rank` (`R1e2`) to `FPGN::to_string` (`FPGN.cpp:145-220`,
  `FPGN.hpp:59-64`); `tight`/`medium`/`full`/`uci` keep their meaning for the bridge
  (`FEngineMoveNode.mm:27`, `FEngineInfo.mm:87`).

### Step 7 — `setFEN` starts from a new board (B6)

- `FFEN::setFEN`: replace `board.clear()` with `board.reset(); board.clear();`, so every field
  the FEN omits takes the value a new board has (KQkq, no ep, clocks 0 and 1) — exactly what both
  callers saw before on a fresh board and what `ChessGame::setFEN` sees after its `reset()`. The ep
  square is assigned, not ORed (`FFEN.cpp:203`).
- A static helper in `FFEN.cpp` then drops any right whose king or rook is not on its home square
  (e1/h1, e1/a1, e8/h8, e8/a8). Together with step 1 this keeps "right held ⇒ king and rook at home"
  true for every board, which the generator assumes.
- `ChessBoard::clear()` itself is unchanged (`reset()` relies on it clearing only the pieces).

### Step 8 — Nits

Fix the `Move.hpp:18-19` comment. Delete `ChessBoard::undo_move` (`ChessBoard.hpp:70`,
`ChessBoard.cpp:350-352`) and its call at `BoardHashTests.cpp:37`; a half-working undo invites a
caller that trusts it. No behaviour change.

### Reuse

`ChessMoveGenerator::generateMoves`, `ChessBoard::move`, `ChessBoardHash::hash` (the from-scratch
reference for the walk), `FFEN::setFEN/getFEN`, `FPGN::setGame/getGame`, the public
`ChessMinMaxSearch::alphabeta` with `maxDepth = 0` to reach quiescence (as `SearchChessTests.cpp`
and `BestMoveTests.cpp` call it), `ChessEngine::setPGN/canPlay` (as `ChessEngineTests.cpp:86-108`),
the `GTestRunner` / `EngineGoogleTests.swift` runner. No new test helper library: each helper lives
in the one test file that uses it.

## Alternatives rejected

- **A castling mask table indexed by square (Stockfish style)** — equivalent; four comparisons are
  simpler here and need no table.
- **Clearing the ep move's capture flag** instead of guarding the capture block — SAN, move sorting
  and quiescence read the flag.
- **Hashing ep whenever the square is set** — simpler, but the position after every double push
  would never repeat the same arrangement without it; FIDE treats them as equal unless a capture is
  possible. **Pseudo-legal ep only (a pawn attacks the square)** — revision 1's design; Codex round 1
  showed it miscounts repetition when the capture would expose the king
  (`k3r3/8/8/3pP3/8/8/8/4K3 w - d6`), and the exact check costs only a board copy in the rare case a
  pawn is adjacent.
- **Fail-hard quiescence (return alpha)** — `alphabeta` is fail-soft and stores `bestValue` in the
  TT; mixing conventions corrupts bounds. The comment above `quiescence` already argues for
  returning the score.
- **`DISABLED_` deep perft cases** — `GTestRunner` drops `DISABLED_` cases from the list
  (`GTestRunner.mm`, `GoogleTestDisabledPrefix`) unless `--gtest_also_run_disabled_tests` is
  passed to the test process, which no gate or scheme does, so they would be dead code. The full
  depths stay in the standalone harness (below).
- **Defaulting a missing castling field to `-`** — would change what 2-field FENs did before (KQkq
  on a fresh board and through `ChessGame::setFEN`), so a stored game from such a FEN that castled
  would stop opening. New-board defaults plus the sanity drop keep old behaviour where it was legal.
- **A deeper hash walk (position 3 d5, Kiwipete d4)** — measured at -O0 after the fix: 1.8 s and
  18 s, far past the CI budget. The shallower walk already fails on `main` (the 153 / 97 mismatches
  quoted in the review are the position 3 d4 / Kiwipete d3 figures; d5 / d4 find 3477 / 6160).
- **Deep perft behind a Release or nightly switch** — the gates run the Debug test bundle only and
  there is no nightly job, so the switch would never be on; the harness covers full depths.
- **Score equality with the TT on and off** — not an invariant here: TT cut-offs from shallower or
  bound entries legitimately change the result (`BestMoveTests.WithAndWithoutTT` expects different
  lines). Move-order equality with the TT off is the sound version and is in step 4.
- **Mate-in-N tests** — without distance-to-mate the engine may pick any mating move at equal score;
  they belong with mate distance, which ENGINE-2 owns.
- **Folding the other review risks in** (50-move rule, insufficient material, TT-before-draw,
  mate distance, quiescence in check, `MoveList::addMoves` colour) — each changes search results
  and needs its own tests and tuning; mixing them in would make the best-move changes here
  impossible to attribute. Listed as follow-ups.

## Test plan

Engine-only C++ fixes are tested with GoogleTest cases in `BChessTests/` (the existing convention for
the engine; each runs as its own Swift Testing case through `EngineGoogleTests.swift`). No Swift code
changes, so no new Swift test. Each test is shown red on the unfixed code before its fix.

| Step | Test (file) | Proves | Red on `main` |
|---|---|---|---|
| 1 | `Perft.StartPosition` d1–d4 = 20 / 400 / 8902 / 197281, `Perft.Position3` d1–d5 = 14 / 191 / 2812 / 43238 / 674624, `Perft.Position4` d1–d4 = 6 / 264 / 9467 / 422333, `Perft.Position6` d1–d3 = 46 / 2079 / 89890 (`PerftTests.cpp`; every depth asserted, so a failure names the shallowest wrong depth) | Move generation and `move()` match the reference counts | no (guards) |
| 1 | `Perft.Kiwipete` d1–d4 = 48 / 2039 / 97862 / 4085603 | Rook captured on h8/a8 loses the right | yes, d4 4085659 |
| 1 | `Perft.Position5` d1–d3 = 44 / 1486 / 62379 | Rook captured on h1 loses the right | yes, d3 62416 |
| 1 | `Perft.CapturedRookLosesCastling`: `4k2r/8/8/8/8/8/8/4K2R w Kk - 0 1`, Rxh8+ → `4k2R/8/8/8/8/8/8/4K3 b - - 0 1` | The fix in one readable case (a8/h8 side) | yes, `b k` |
| 1 | `Perft.CapturedRookOnH1LosesCastling`: position 5, play c4f7 (Bxf7) then f2h1 (Nxh1); White's `K` is gone and no e1g1 is generated | The a1/h1 side, on the exact failing perft path | yes |
| 2 | `Perft.HashMatchesFromScratchAtEveryNode`: walk Kiwipete d3, position 3 d4, position 4 d3; at every node `board.getHash() == ChessBoardHash::hash(board)` (`PerftTests.cpp`, same walker with a hash flag) | Incremental hash is exact across ep, castling, promotion, captures | yes, 97 / 153 bad nodes |
| 2 | `BoardHash.EnPassantKeepsHashExact`: the B2 repro (`BoardHashTests.cpp`) | B2 in one case | yes |
| 3 | `BoardHash.CastlingAndEnPassantChangeTheHash`: `r3k2r/8/8/8/8/8/8/R3K2R w KQkq -` ≠ same with `Kkq`; `4k3/8/8/3pP3/8/8/8/4K3 w - d6` ≠ same with `-`; after 1. e4 (`…b KQkq e3`) == same with `-` (no black pawn can take) | Rights and legal ep are in the hash; an unusable ep square is not | first two yes, third no (guard) |
| 3 | `BoardHash.EnPassantInTheHashOnlyWhenLegal`, Black to move and two-candidate cases: `4k3/8/8/8/3Pp3/8/8/4K3 b - d3 0 1` ≠ same with `-` (exd3 legal); `4k3/8/8/8/3Pp3/8/8/K3R3 b - d3 0 1` == same with `-` (exd3 opens the e-file); `4K3/8/8/8/k2Pp2R/8/8/8 b - d3 0 1` == same with `-` (rank-4 exposure); `4k3/6b1/8/2PpP3/8/2K5/8/8 w - d6 0 1` ≠ same with `-` (e5 pinned, c5 can take); `8/8/2k5/8/2pPp3/8/6B1/4K3 b - d3 0 1` ≠ same with `-` (e4 pinned, c4 can take). For each "≠" case, play the legal ep capture and assert `getHash() == ChessBoardHash::hash(board)` | Inclusion and exclusion follow the rules for either side and either candidate; expectations from python-chess `has_legal_en_passant()` (true, false, false, true, true, checked) | "≠" cases yes (ep not hashed on `main`); "==" cases shown red against the stubbed legality check, as below |
| 3 | `BoardHash.IllegalEnPassantIsNotInTheHash`: `k3r3/8/8/3pP3/8/8/8/4K3 w - d6 0 1` == same with `-` (exd6 opens the e-file to the rook); `8/8/8/K2pP2r/8/8/8/4k3 w - d6 0 1` == same with `-` (both pawns leave rank 5, the rook sees the king); `4k3/6b1/8/3pP3/8/2K5/8/8 w - d6 0 1` (e5 pinned on the c3–g7 diagonal) == same with `-` | The expectation comes from the rules (python-chess `has_legal_en_passant()` is false for all three while `has_pseudo_legal_en_passant()` is true, checked), not from `hash()` | no on `main` (ep is not hashed at all); it is the guard that fails against a pseudo-legal step 3 (a pawn attacks d6 in each), and is shown red that way: run it once with the legality check stubbed out |
| 3 | `ChessEngineTests.CastlingRightsMakeAPositionDifferent`: `1. Nf3 Nf6 2. Rg1 Rg8 3. Rh1 Rh8 4. Ng1 Ng8 5. Nf3 Nf6 6. Ng1 Ng8 *` → `canPlay()` true; two more knight round trips → false | Repetition follows FIDE rights | yes (false) |
| 3 | The step-2 walk now also checks the state keys | `stateKey` is maintained incrementally | — |
| 4 | `MinMaxSearchTests.SortingDoesNotChangeTheScore`: TT off, score with `sortMoves` on == off for Kiwipete at `maxDepth` 0 and `r1bqkbnr/pppp1ppp/2n5/4p3/4P3/5N2/PPPP1PPP/RNBQKB1R w KQkq - 2 3` at 0–2 (≈0.35 s at -O0) | Alpha-beta and quiescence return the true minimax value whatever the move order | yes: Kiwipete d0 50 vs −640, the other d2 −15 vs 20 (with the B3 fix: equal at every depth, checked in a scratch copy) |
| 4 | `MinMaxSearchTests.QuiescenceReturnsTheBestCapture`: `k7/3r4/1p6/2p5/3Q4/8/8/K7 w - - 0 1` (captures sorted Qxd7 then Qxc5; Qxc5 loses the queen to bxc5); `alphabeta` with `maxDepth = 0`, TT off; score == `ChessEvaluater::evaluate` of the position after Qxd7 (Black has no capture there), PV == `Qd4xd7`, and the score is above the stand-pat | Best, not last and not stand-pat; PV matches the score | yes: `main` returns 310 (the Qxc5 line) with PV Qxd7; the fixed copy returns 705 with PV Qxd7; stand-pat 210 |
| 4 | `MinMaxSearchTests.QuiescenceNeverBelowStandPat`: B3 repro, its colour mirror with Black to move, and a quiet position; `alphabeta` with `maxDepth = 0`, TT off; White to move: result ≥ `ChessEvaluater::evaluate`, Black to move: ≤ | B3 | yes, −220 < −200 |
| 5 | `EvaluationTests.MirroredPositionsScoreOpposite`: a `mirrorFEN` helper in the test file (reverse ranks, swap case, swap side, swap castling case, ep rank 3↔6); start position, White-only pair, Black-only pair, Kiwipete, positions 4, 5, 6: `evaluate(p) == -evaluate(mirror(p))`, and the start position scores 0 | B4 and evaluation symmetry | yes (640 vs −590; start +50) |
| 6 | `PGN.EngineOutputRoundTrips`: from `8/1P6/8/8/8/8/8/1k2K3 w - - 0 1` play b8=Q; `getGame` contains `b8=Q+`; `setGame` of that text succeeds and reaches the same FEN | B5 promotion + check | yes |
| 6 | `PGN.RankAndSquareDisambiguation`: `4k3/8/8/8/8/4R3/4p3/4R1K1 w - - 0 1` Re1xe2 is written `R1xe2+` and read back; `4k3/8/8/8/8/Q7/8/Q1Q1K3 w - - 0 1` Qa1-b2 is written `Qa1b2`; a file case (`Rae1`-style) is unchanged | Writer uses minimal SAN; parser reads each form | yes (`Re1xe2+`, then parse) |
| 6 | `PGN.NAGsAndAnnotationsAfterCheck`: `1. e4 $1 f5 $2 2. Qh5+! g6 $14 *` parses to 4 moves; `1. e4 (1. d4 d5) $1 e5 *`, `1. e4 $1 {c} (1. d4) {d} $2 e5 *` and `1. e4 {c} $1 e5 *` each parse to 2 main-line moves with the variation kept | NAGs, comments and variations in any order; `+!` | yes |
| 6 | `PGN.PromotionPieceMustBeExplicit`: from `8/1P6/8/8/8/8/8/1k2K3 w - - 0 1`, `1. b8=Q+`, `=R`, `=B`, `=N` parse to the matching promotion; `1. b8= *`, `1. b8=K *`, `1. b8=P *`, `1. b8=X *` fail | Only Q/R/B/N promote | `=K`/`=P`/`=X` red (mapped to a piece or pawn today); `b8=` red |
| 6 | `PGN.MalformedInputFails`: `1. e4 2. d4` and `[Event] 1. e4 *` return false | No assert on bad input | yes (Debug assert aborts — the red run is a crash, recorded as such) |
| 7 | `FEN.SetFENDoesNotInheritState` (new `FENTests.cpp`): reuse one board for `4k3/8/8/3pP3/8/8/8/4K3 w - d6 0 1` then `4k3/8/8/8/8/8/8/R3K2R w KQ e3 5 9` (ep is exactly e3) then `4k3/8/8/8/8/8/8/4K3 b` (→ `4k3/8/8/8/8/8/8/4K3 b - - 0 1`); FEN and hash equal to the same FEN on a fresh board | B6 | yes |
| 7 | `FEN.ImpossibleCastlingRightsAreDropped`: `4k3/8/8/8/8/8/8/4K3 w KQkq - 0 1` → castling `-` and no castling move generated; `r3k2r/8/8/8/8/8/8/R3K2R w` keeps `KQkq` | No conjured rook from input; old 2-field behaviour kept | first yes, second no (guard) |

`EngineGoogleTests.registersAllCases` (floor `>= 115`) is raised to the new total in each step that
adds cases.

**Time budget.** Measured with the harness at `-O0` (what the Debug test bundle uses): start d4
35 ms, Kiwipete d4 880 ms, position 3 d5 160 ms, position 4 d4 110 ms, position 5 d3 15 ms,
position 6 d3 25 ms (≈1.2 s; the shallower depths add little); the hash walk ≈0.35 s once fixed;
the sorting test ≈0.35 s. Target ≤ 2 s for `Perft.*` in the
Debug run; the implementer reports the measured time. If over budget, lower position 3 to d4 first;
never lower the two red cases (Kiwipete d4, position 5 d3).

**Full depths** stay in the standalone harness, committed in `planning/assets/ENGINE-1/`:

```
E=Shared/Engine; I=$(find $E -type d | sed 's/^/-I/')
clang -O2 -c $E/Helpers/magicmoves.c -o /tmp/magic.o $I
clang++ -std=c++20 -O2 -w $I planning/assets/ENGINE-1/perft.cpp $(find $E -name '*.cpp') /tmp/magic.o -o /tmp/perft && /tmp/perft
```

(`divide.cpp` builds the same way; `compare.py` needs `pip install chess` and `./divide` in the
working directory; it bisects a mismatch down to the first wrong position.) Run once after step 1 and
once at the end: every depth OK, and the Mnps figure reported before/after step 3 (the state key is
two cheap calls per move; a drop over 10 % is reported, not silently accepted).

### Best-move tests that change

Steps 3–5 change scores (B4 alone shifts every evaluation where one side has the pair — the start
position by 50), so `BestMoveTests`, `SearchChessTests` (e.g. `ChessTree` expects a score of 50 from
the start position, which includes Black's bogus pair bonus) and possibly TT-dependent lines
(`BestMoveTests.WithAndWithoutTT`) may legitimately change. Rule, per changed test:

1. Never update an expectation in the same edit as the fix without the record below; the record goes
   in the step's commit message.
2. Record old and new line and score, and confirm the old expectation comes from the bug: revert only
   the step's engine change and see the old value come back.
3. Judge the new line with Stockfish (decision 1: Homebrew, developer tool only; accept when the new
   first move is within 30 centipawns of Stockfish's best at depth 20 and not worse than the old one). The test's stated intent
   (its comment: "pawn fork", "knight escapes", "black king is about to get mate") must still hold.
4. If the new line is worse by the judge, or the intent no longer holds, **stop and report** — do not
   update the test; it points at a real problem.
5. Pure node-count expectations (`SearchChessTests` `visitedNodes`) may be updated with the record
   from (2) alone.

The 115 GoogleTest cases and 112 Swift tests must otherwise stay green; any other change is a stop.

## Invariants

- **I1 — Files keep opening.** *Narrowed by Jean's decision 2.* Games are stored as PGN
  (`GameState.pgn`, `Shared/Model/GameState.swift:32`) and re-parsed against the legal moves. A
  stored game that contains a castle made possible only by B1 (e.g. position 5 then
  `8. Bxf7 Nxh1 9. O-O *`, which opens today), or by a FEN claiming impossible rights, no longer
  parses after steps 1 and 7. Step 1 adds that exception to I1 in `AGENTS.md`; BChess has not
  shipped (App Store Connect: 1.0 "Prepare for Submission" on both platforms), so such files can
  exist only on Jean's devices. Held otherwise: the parser only accepts
  more (every file that opened still opens, `OpeningsTests` and the PGN corpus tests stay green); the
  writer still writes standard PGN and becomes more standard (`R1xe2` instead of `Re1xe2`). Older
  BChess versions cannot read `R1xe2`, but they already cannot read their own `b8=Q+`. Missing FEN
  fields keep their previous defaults (step 7). Hashes are never persisted.
- **I2 — A search result only lands on its position.** Not applicable: no change to search
  scheduling, cancellation or callbacks. The TT key gains state, which only reduces wrong reuse.
- **I3 — Portable engine.** Holds: plain C++ in `Shared/Engine/`; tests and the harness use only the
  engine headers.
- **I4 — UCI keeps working.** Holds. `position fen … moves …` now gets correct rights and hashes;
  the `BChessUCI` build gate covers it.
- **I5 — Private and offline.** Holds. Stockfish, the judge for changed best-move tests, is a
  developer tool on Jean's Mac, never linked or shipped.

## Risks and rollout

- Playing strength and move choice change (B3, B4, R1 together). Expected and intended; the
  best-move rule above keeps it reviewed.
- A wrong `stateKey` maintenance would make the TT and repetition silently wrong; the per-node hash
  walk is the guard and runs in CI.
- The castling assert (step 1) fires only in Debug; Release behaviour is the fix itself.
- Nothing needs a real device: engine-only, covered by the macOS test gate; the iOS gate and the UCI
  build gate run as usual.

## Follow-ups (ENGINE-3 candidates, not in this plan)

ENGINE-2 is the UCI plan (`planning/ENGINE-2-uci-and-elo.md`); it owns the UCI promotion suffix in
`FPGN::to_string(…, SANType::uci)` (`FPGN.cpp:152`) and the unchecked `ChessBoard::getMove`
(`ChessBoard.cpp:364`). This plan touches neither (step 6 only adds `SANType::rank`).

Correctness:

- Quiescence horizon at depth 4 (found in step 4): stand-pat with two pieces attacked after a check
  sequence (`1...Bb4+ 2.c3 Qe7+ 3.Ne2`, Black to move with bishop and knight attacked) scores as if both
  were saved. Candidate remedies: check extension, threat detection in quiescence.
- Draws: fifty-move rule (`halfMoveClock` is kept but unused) and insufficient material.
- Search: probe the TT after `isDraw` and do not store repetition-dependent 0s. (Mate distance is
  in ENGINE-2 r2, which also changes `IterativeDeepening` and `MinMaxSearch`; the step-4 tests here
  assert relations, not node counts, so they survive it.)
- Quiescence when in check (generate evasions instead of standing pat).
- `MoveList::addMoves` tags moves with `board.color` (`MoveList.cpp:74`) instead of the generating
  side; affects only `positionalAnalysis` (off by default) and will change `EvaluationTests` values.
- Tests that come with those: fifty-move rule, repetition over a long history. (Mate-in-N belongs
  with ENGINE-2's mate distance.)

Performance (from the performance review, not re-measured here):
- `stateKey` costs about 20-25 % of standalone perft speed (start d5 ~45 to ~35 Mnps, Kiwipete d4 ~50
  to ~37, measured in step 3): maintain the state key incrementally instead of recomputing it twice per move.
- TT best move first plus killer moves in move ordering (reported −29 % / −43 % nodes).
- Bound the repetition scan by the half-move clock (`GameHistory.cpp:12-23` scans the whole history).
- Quiescence cost (no delta pruning or SEE; it searches every capture).
- The transposition table is allocated (≈549 MB, calloc in the constructor) for every `FEngine`,
  including short-lived probe engines.

## Decisions (Jean, 2026-10-06)

1. **Judge for changed best-move tests:** Stockfish via Homebrew, developer tool only, never shipped.
   A new line is accepted when its first move is within 30 centipawns of Stockfish's best at depth 20
   and not worse than the old one.
2. **Saved games with a castle only the bug allowed (I1):** accept; narrow I1. Step 1 changes
   `AGENTS.md` I1 from:

   > **I1 — Files keep opening.** Every game file an earlier BChess wrote (`.json` with the
   > `GameState` shape, `.pgn`) still opens, and PGN written by BChess stays standard PGN.

   to:

   > **I1 — Files keep opening.** Every game file an earlier BChess wrote (`.json` with the
   > `GameState` shape, `.pgn`) still opens, and PGN written by BChess stays standard PGN. The one
   > exception is a game whose moves are illegal chess that only an engine bug let BChess accept
   > (ENGINE-1: castling after the rook was captured on its corner, or with castling rights a FEN
   > claimed without king and rook in place); BChess had not shipped when that was fixed, so such
   > files can exist only on the developer's own devices.

   Considered and not chosen: a legacy load path that re-parses failing games with the pre-fix
   castling rule. It would keep an illegal-move path (and its rook-conjuring, hash-breaking castle)
   alive in the engine permanently for a handful of files on Jean's own devices. Codex round 2's
   blocker and its legacy-hash item were about that path and are moot.
3. **Minimal SAN in exported PGN (`R1xe2`):** yes.
4. **Scope:** as planned (B1–B6, castling and en passant in the hash, nits); the other risks are
   ENGINE-3 candidates. Go.

5. **Step 4 (B3) best-move fallout (Jean, 2026-10-06): keep the fix, adjust the tests.**
   `KnightEscapeAttackByPawn` now runs at `maxDepth` 5 (depth 4 picks `Bf8b4` through the horizon effect
   listed in the follow-ups; depth 5 plays `Nc6e5`, Stockfish -100 cp vs best -94). `WhiteThreatenMate` accepts
   `f7f6` (Stockfish's best at depth 20; the old `Rd8d7` was -444 cp against -292 cp). `WithAndWithoutTT`
   becomes a smoke test (both configurations complete with a legal move and a sound score), since a table
   legitimately changes the line. `SearchChessTests.OrderedMove` (same horizon effect on the same family of positions) goes from 23846/136314 nodes and score 105 to 39168/311437 and 50. Standing rule for steps 5-8: adjust a best-move test this way when its purpose
   still holds, document it in the commit; stop only when the purpose genuinely fails.
6. **Widen the I1 exception to ENGINE-1 illegal moves (Jean, 2026-10-06; Codex code review round 3).**
   A saved PGN such as `[FEN "4k3/8/8/4P3/8/8/8/4K3 w - d6 0 1"] 1. exd6 *` (an en passant capture with no
   pawn to capture) opened before ENGINE-1 and no longer does, because `setFEN` drops an en-passant square
   nothing can capture and the generator no longer offers the move. Accepted, no code change: the `AGENTS.md`
   I1 exception now names both cases (castling made possible only by the rook-capture or FEN-rights bugs, and
   an en passant capture with no pawn to capture or onto an occupied square). `PGN.IllegalEnPassantGameNoLongerOpens`
   documents it.
