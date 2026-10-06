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
- **Time control:** 10+0.1 by default, with a time margin of 100 ms. A draw is adjudicated after
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
- **the score is out of range:** below 10 % or above 90 %, or fastchess gives no finite interval. It
  prints the level to try next (300 further, at least 1320) and exits with status 3.

**How long it takes** on an M2 with a concurrency of 4: a 10+0.1 game lasts at most
2 × (10 + 0.1 × moves) s, about 25 s of wall time with adjudication, so 300 games take about
30 minutes. At 60+0.6 the same run takes about 3 hours.

## Caveats

- Stockfish's `UCI_Elo` is calibrated to CCRL Blitz, approximately (the comment on `Skill` in
  Stockfish's `search.h`), at a longer time control than 10+0.1. At 10+0.1 the number is indicative.
- The rating is relative to that anchor. It is not a FIDE or a CCRL rating.
- A limited-strength Stockfish plays its weaker moves differently from a human of that rating, and
  from other engines.
- What the number reflects in BChess: no transposition table in the tool, no fifty-move rule, and
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

The first row is the probe that picked the level for the second. The second is the measurement:
`LEVEL=1800 GAMES=300 scripts/elo-match.sh` (10+0.1, concurrency 4, Apple M2, Stockfish 19,
fastchess v1.8.2-alpha). Score 40.8 %, Elo difference to Stockfish 1800 of −64 ± 40 (95 %). No
illegal move, time forfeit, disconnect or stall in either run. BChess at this commit therefore
plays at about 1740 ± 40 on Stockfish's `UCI_Elo` scale at 10+0.1.
