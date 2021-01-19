#  What remains to be done

- Finish Zobrist hashing unit test with all the scenarios: castling, attack, etc.
- Ensure that when a Game is copied, the history is also copied, not just referenced because it will get messed up (see FEngineInfo)
- Better handling of openings when a FEN is passed (and the board is not in the expected state for the opening)
- Handle UCI move with promotion (for example h1b1q)
- Time management in UCI
- Add 3 fold repetition rule
- Add 50 moves rule
- Add heuristic to add bonus when king is safely behind its raw of pawns after castling
- Add more openings
- Transposition table [here](http://www.chessbin.com/post/Transposition-Table-and-Zobrist-Hashing) and [here](https://chessprogramming.wikispaces.com/Transposition+Table)
- [Optimization](https://people.cs.clemson.edu/~dhouse/courses/405/papers/optimize.pdf)
