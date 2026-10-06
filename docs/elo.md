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
  off and no opening book (the tool loads none).
- **Time control:** 10+0.1 by default, with a time margin of 100 ms (`TIMEMARGIN=<ms>`, applied to both engines and written to the run's `.info` file; ENGINE-3's late matches used 200 ms because scheduler jitter on a loaded machine caused forfeits of 100 to 150 ms). A draw is adjudicated after
  move 40 when both scores stay within 10 cp for 8 moves; a game ends when both engines agree that
  one side is 10 pawns up for 4 moves.
- **Tools are checked on every run:** Stockfish 19, and fastchess at the pinned commit (also when
  cached or found on `PATH`). Each run writes `.elo/runs/<stamp>-SF<level>.info` with the versions,
  the sha256 of both binaries and of `BChessUCI`, the commit and whether the tree was dirty, and the
  opening seed (`SEED=<n>` repeats a run's openings).
- **One level per run.** The result is the Elo difference to that level, with fastchess's 95 %
  interval. There is no combined multi-level estimate.

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
- **the score is out of range:** below 10 % or above 90 %, or fastchess gives no finite interval. It
  prints the level to try next (300 further, at least 1320) and exits with status 3.

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
- What the number reflects in BChess: the transposition table orders moves but never cuts off (it is off for cut-offs in the tool), no fifty-move rule, and
  no quiescence search while in check.
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

The first row is the probe that picked the level for the second. The second is the measurement:
`LEVEL=1800 GAMES=300 scripts/elo-match.sh` (10+0.1, concurrency 4, Apple M2, Stockfish 19,
fastchess v1.8.2-alpha). Score 40.8 %, Elo difference to Stockfish 1800 of −64 ± 40 (95 %). No
illegal move, time forfeit, disconnect or stall in either run. BChess at this commit therefore
plays at about 1740 ± 40 on Stockfish's `UCI_Elo` scale at 10+0.1.

ENGINE-3 (speed: a faster search at the same evaluation, delta pruning in quiescence; the transposition table orders moves but does not cut off) is in the next two rows, with a 200 ms time margin for both engines (`TIMEMARGIN=200`, in the run info) after forfeits of 100 to 150 ms on a loaded machine. The first is the 40-game probe that picked the level. The second is the measurement: 300 games, no forfeit, score 42.2 %, Elo difference to Stockfish 2000 of -54.9 ± 39.4. Against ENGINE-2 itself (`BASE=2eb86d5 TIMEMARGIN=200 scripts/elo-match.sh`, SPRT [0, 10], 5+0.05) H1 was accepted after 208 games, 142/49/17, +241 ± 51 Elo, LLR 2.95.
