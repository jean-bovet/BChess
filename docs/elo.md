# BChess's Elo

How strong is BChess? `scripts/elo-match.sh` plays it against Stockfish at a chosen `UCI_Elo` level
with [fastchess](https://github.com/Disservin/fastchess) and reports the score, the Elo difference
and its error bar. The number is a measurement of one build at one time control against one
reference; read it with the caveats below.

## Method

- **Opponent:** Stockfish from Homebrew (`brew install stockfish`), with `UCI_LimitStrength` on and
  `UCI_Elo` set to the level (1320 is the lowest it accepts), one thread, 16 MB of hash.
- **Runner:** fastchess, built from a pinned tag (`v1.8.2-alpha`, commit `f618e34`) into the
  git-ignored `.elo/` folder the first time the script runs. Nothing binary is committed.
- **Openings:** `8moves_v3.pgn` from `official-stockfish/books`, downloaded from a pinned commit and
  checked against its sha256. Every opening is played twice, once with each colour.
- **BChess:** `BChessUCI`, built in Release from the current checkout, with the transposition table
  cutting off at non-PV nodes (always on since ENGINE-3 search; it was off for cut-offs before) and no
  opening book (the tool loads none).
- **Time control:** 10+0.1 by default, with a time margin of 100 ms (`TIMEMARGIN=<ms>`, applied to both engines and written to the run's `.info` file; ENGINE-3's late matches used 200 ms because scheduler jitter on a loaded machine caused forfeits of 100 to 150 ms). A draw is adjudicated after
  move 40 when both scores stay within 10 cp for 8 moves; a game ends when both engines agree that
  one side is 10 pawns up for 4 moves.
- **Tools are checked on every run:** Stockfish 19, and fastchess at the pinned commit (also when
  cached or found on `PATH`). Each run writes `.elo/runs/<stamp>-SF<level>.info` with the versions,
  the sha256 of both binaries and of `BChessUCI`, the commit and whether the tree was dirty, and the
  opening seed (`SEED=<n>` repeats a run's openings).
- **One level per run.** The result is the Elo difference to that level, with fastchess's 95 %
  interval. There is no combined multi-level estimate.

## The strength levels (APP-3)

The New Game sheet offers five computer levels, each a handicapped version of the engine
(`Shared/Engine/Algorithm/Handicap.hpp`: a depth cap, randomness among the scored root moves, and tactical
blindness). Maximum is the full engine and keeps the figure of the table below (ENGINE-3 search step 13:
2364 +/- 36 at 10+0.1). The other four were measured on 2026-10-23 (APP-3 step 7, commit of the table
`c6deb0b`, Club and Strong at `2c452bb` with the same rows, `scripts/elo-match.sh`, TC 40+0.4, `TIMEMARGIN=200`, concurrency 8, 300 games each, openings
`8moves_v3`, no forfeit, illegal move or malformed game in any run):

| Level | Measured (95 %) | Label | Target | Handicap {depth, temperature, blindness} | Measured against |
|---|---|---|---|---|---|
| Beginner | 538 +/- 98 | about 550 | 600 | {1, 10, 0.1} | BChess Casual: 22/12/266, -395 +/- 66 |
| Casual | 933 +/- 72 | about 950 | 1000 | {2, 25, 0.2} | BChess Club: 17/21/262, -398 +/- 60 |
| Club | 1331 +/- 39 | about 1350 | 1400 | {3, 25, 0.0} | Stockfish UCI_Elo 1350: 139/6/155 |
| Strong | 1624 +/- 40 | about 1600 | 1700 | {5, 8, 0.0} | Stockfish UCI_Elo 1700: 109/17/174 |
| Maximum | 2364 +/- 36 | about 2350 | 1950 | the full search | Stockfish, 10+0.1 (ENGINE-3 search step 13) |

- **The chain.** Club and Strong are Stockfish performances. Each had a probe first: Club 40 games at 1400 (40+0.4,
  1347 +/- 88), Strong 20 games at 1700 (60+1, 1665 +/- 164, which also timed its moves). Casual is Club plus the self-play difference, Beginner is Casual plus its difference, and each
  step adds its error in quadrature (the figures above include it). Stockfish cannot play below 1320, so the two lowest levels
  carry the wider error and are only as good as Club's figure. A level's number is only meaningful on this scale at this time control.
- **The clock.** The handicapped levels ignore the clock, but their search cannot be cut. A 20-game timing probe of Strong (60+1,
  eight games at once) gave a longest move of 0.34 s (mean 0.05 s), so 40+0.4 leaves 80 such moves a large margin.
- **Tuning.** The first table (Beginner {1, 150, 0.5}, Casual {2, 60, 0.2}) scored 0 % and 2 % in 300 games against Casual and
  Club, about 650 and 400 Elo below their targets. Beginner and Casual were tuned (temperature first; Beginner's blindness
  had to fall from 0.5 to 0.1, since at depth 1 blindness dominates) on exploration runs, then measured on the committed table.
  Club and Strong are within 100 of their targets and were not touched.
- **Maximum is far above Strong:** 740 Elo from Strong to Maximum. A level between them would be Jean's decision.

## How to run

```
scripts/elo-match.sh                                      # 300 games against Stockfish 1600, 10+0.1
LEVEL=1400 GAMES=100 TC=10+0.1 CONCURRENCY=4 scripts/elo-match.sh
```

`LEVEL` is Stockfish's `UCI_Elo`, `GAMES` is even, `CONCURRENCY` is the number of games played at
once (4 on an M2: its four performance cores; the efficiency cores only add noise). A smoke run
that takes under a minute: `LEVEL=1320 GAMES=4 TC=2+0.05 scripts/elo-match.sh`.

The script builds, plays, and prints a Markdown row for the table below. It refuses to give a number when:

- **the run is invalid:** an illegal move, a disconnect, a stall or an unfinished game, or a PGN
  that does not hold exactly `GAMES` complete games (each with one result and one termination from
  the allowed set, one side BChess) agreeing with fastchess's summary. `scripts/elo-match.sh
  --self-test` checks that validator against sample runs. That is a bug
  to fix, not a rating. It exits with status 2.
- **a side lost a game on time:** a `time forfeit` termination by either engine makes the run
  invalid (exit 2). A forfeit by the opponent would otherwise inflate BChess's score. ENGINE-2's
  runs had none, so the results recorded below stand.
- **a Stockfish run's score is out of range:** below 10 % or above 90 %, or fastchess gives no finite
  interval. It prints the level to try next (300 further, at least 1320) and exits with status 3. A self-play run
  (`STRENGTH` with `OPPONENT_STRENGTH`) has no such limit: it reports the difference and interval as fastchess gives
  them, which at a score of 0 or 100 % is an infinite difference and an undefined interval (`--self-test` covers both).

**How long it takes** on an M2 with a concurrency of 4: a 10+0.1 game lasts at most
2 × (10 + 0.1 × moves) s, about 25 s of wall time with adjudication, so 300 games take about
30 minutes. At 60+0.6 the same run takes about 3 hours.

## A/B (SPRT)

`BASE=<git ref> scripts/elo-match.sh` plays this checkout against an earlier commit instead of
Stockfish, to decide whether a change makes BChess stronger:

```
BASE=2eb86d5 scripts/elo-match.sh                        # SPRT [0, 10], 5+0.05, at most 8000 games
BASE=HEAD~1 MAX_GAMES=4000 TC=5+0.05 CONCURRENCY=4 scripts/elo-match.sh
BASE=HEAD~1 ELO0=-5 ELO1=0 scripts/elo-match.sh          # non-regression: H1 means no loss beyond -5 Elo
```

- **Base build:** `git archive <ref>` is extracted into `.elo/base/<sha>` and built there in
  Release (cached by sha). The checkout is built as before, uncommitted changes included, and the
  `.info` file says whether the tree was dirty.
- **The test:** fastchess's SPRT, `elo0=0 elo1=10 alpha=0.05 beta=0.05 model=logistic`, stops when
  the log-likelihood ratio (LLR) leaves its bounds (about ±2.94) or at `MAX_GAMES`. W/D/L are
  BChess's, as always; the other engine is called `Base`.
- **Reading the result:**
  - exit 0, "H1 accepted": the change is worth at least about 0 to 10 Elo. It lands.
  - exit 4, "H0 accepted": no gain was shown. It does not land.
  - exit 5, "inconclusive at MAX_GAMES": no decision, so it does not land either.
  - exit 2, invalid run: an illegal move, a time forfeit by either engine, a disconnect, an
    unfinished game, a PGN that disagrees with fastchess's summary, or fewer games than
    `MAX_GAMES` without a decision. The decision counts only when the LLR is outside its bounds:
    fastchess prints "H1 was accepted" also when it merely ran out of rounds.
- **How long:** an SPRT of a small gain needs a few thousand games, 1 to 3 hours at 5+0.05 with a
  concurrency of 4. An SPRT can stop between the two games of an opening, so the game count may be
  odd.

`scripts/elo-match.sh --self-test` covers the validator and the decision logic with sample runs.

## Benchmark

`scripts/bench.sh` is the speed benchmark: a fixed-depth search of nine positions (the six perft
positions, two more, and a 130-ply game so that the repetition scan has a long history), built
standalone with plain `clang++ -O2`. It prints each position's nodes, score and best move, a
signature hash over all of them, and the retired instructions (the speed metric: it barely depends
on the load of the machine) and the maximum memory of the run. `scripts/bench.sh --compare old new`
diffs two outputs, and `scripts/bench.sh --perft` runs ENGINE-1's perft check.

## Caveats

- Stockfish's `UCI_Elo` is calibrated to CCRL Blitz, approximately (the comment on `Skill` in
  Stockfish's `search.h`), at a longer time control than 10+0.1. At 10+0.1 the number is indicative.
- The rating is relative to that anchor. It is not a FIDE or a CCRL rating.
- A limited-strength Stockfish plays its weaker moves differently from a human of that rating, and
  from other engines.
- What the number reflects in BChess: the table cuts off at non-PV nodes (never at the root or on the principal
  variation), the fifty-move rule and dead positions are scored as draws, quiescence searches the evasions of a side in
  check, and the search has a check extension, PVS, null move, late-move reductions, aspiration windows, futility and SEE
  pruning. Static evaluation is unchanged (that is the third ENGINE-3 plan).
- The error bars widen as the score moves away from 50 %, which is why the level is chosen near the
  engine's own.

## Error bars

95 %, near a 50 % score, with about 20 % draws (the per-game score variance is about 0.2, and one
score point is about 695 Elo at 50 %):

| Games | ± Elo |
|------:|------:|
| 100 | ±61 |
| 200 | ±43 |
| 300 | ±35 |
| 400 | ±31 |
| 1000 | ±19 |

## Results

| Date | Commit | TC | Book (seed) | Stockfish level | Games | W/D/L | Performance (95 %) | Wall time |
|---|---|---|---|---|---:|---|---|---:|
| 2026-10-06 | c527652 | 10+0.1 | 8moves_v3 (not recorded) | 1600 | 40 | 28/2/10 | 1768 ± 125 | 4 min |
| 2026-10-06 | c527652 | 10+0.1 | 8moves_v3 (not recorded) | 1800 | 300 | 115/15/170 | **1736 ± 40** | 34 min |
| 2026-10-06 | e0c7f01 | 10+0.1, margin 200 | 8moves_v3 (498536314) | 2000 | 40 | 18/3/19 | 1991 ± 116 | 5 min |
| 2026-10-06 | e0c7f01 | 10+0.1, margin 200 | 8moves_v3 (124222418) | 2000 | 300 | 116/21/163 | **1945 ± 39** | 35 min |
| 2026-10-23 | dc5473c | 10+0.1, margin 200 | 8moves_v3 (not recorded) | 2200 | 40 | — | 2337 ± 100 | — |
| 2026-10-23 | dc5473c | 10+0.1 | 8moves_v3 (1011167814) | 2350 | 300 | 138/36/126 | **2364 ± 36** | 20 min |
| 2026-10-23 | 2c452bb Strong | 60+1, 20 games (timing probe) | 8moves_v3 (694249943) | 1700 | 20 | 9/0/11 | 1665 ± 164 | 5 min |
| 2026-10-23 | 2c452bb Club | 40+0.4, margin 200 | 8moves_v3 (546126066) | 1400 | 40 | 16/2/22 | 1347 ± 88 | 6 min |
| 2026-10-23 | 2c452bb Strong | 40+0.4, margin 200 | 8moves_v3 (699535022) | 1700 | 300 | 109/17/174 | **1624 ± 40** | 38 min |
| 2026-10-23 | 2c452bb Club | 40+0.4, margin 200 | 8moves_v3 (214789468) | 1350 | 300 | 139/6/155 | **1331 ± 39** | 37 min |

The first row is the probe that picked the level for the second. The second is the measurement:
`LEVEL=1800 GAMES=300 scripts/elo-match.sh` (10+0.1, concurrency 4, Apple M2, Stockfish 19,
fastchess v1.8.2-alpha). Score 40.8 %, Elo difference to Stockfish 1800 of −64 ± 40 (95 %). No
illegal move, time forfeit, disconnect or stall in either run. BChess at this commit therefore
plays at about 1740 ± 40 on Stockfish's `UCI_Elo` scale at 10+0.1.

ENGINE-3 (speed: a faster search at the same evaluation, delta pruning in quiescence; the transposition table orders moves but does not cut off) is in the next two rows, with a 200 ms time margin for both engines (`TIMEMARGIN=200`, in the run info) after forfeits of 100 to 150 ms on a loaded machine. The first is the 40-game probe that picked the level. The second is the measurement: 300 games, no forfeit, score 42.2 %, Elo difference to Stockfish 2000 of -54.9 ± 39.4. Against ENGINE-2 itself (`BASE=2eb86d5 TIMEMARGIN=200 scripts/elo-match.sh`, SPRT [0, 10], 5+0.05) H1 was accepted after 208 games, 142/49/17, +241 ± 51 Elo, LLR 2.95.

ENGINE-3 search (draws by rule, a table fit for cut-offs, quiescence in check, check extension, PVS, null move, late-move reductions, aspiration windows, futility and SEE pruning; the evaluation is unchanged) is in the next two rows, both at `TIMEMARGIN=200`. The first is the 40-game probe at level 2200 (run 20261023-181039-SF2200, +137 ± 100 Elo). The second is the measurement: 300 games against level 2350 (run 20261023-184110-SF2350, concurrency 8), score 52.0 %, Elo difference to Stockfish 2350 of +13.9 ± 35.7, no forfeit, 20 minutes. Against ENGINE-3 speed's base `4986ad7` (SPRT [0, 10], 5+0.05, `TIMEMARGIN=1000`, concurrency 8, run 20261023-164152) H1 was accepted after 208 games, 170/32/6, +370.84 ± 59.95 Elo, LLR 2.95. One earlier 300-game run (20261023-181331-SF2350) is not a result: the Mac slept for 17 minutes during it (pmset 18:13:37 to 18:31:27) although `caffeinate -i` was running, and both engines forfeited 20 games on time; the valid run was wrapped in `caffeinate -dims`, and the script now uses `caffeinate -ims`.
