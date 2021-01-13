#  BChess

## ToDo

- Add promotion support in SwiftUI
- Finish Zobrist hashing unit test with all the scenarios: castling, attack, etc.
- Ensure that when a Game is copied, the history is also copied, not just referenced because it will get messed up (see FEngineInfo)
- Better handling of openings when a FEN is passed (and the board is not in the expected state for the opening)
- Handle UCI move with promotion (for example h1b1q)
- Add 3 fold repetition rule
- Add 50 moves rule
- Add heuristic to add bonus when king is safely behind its raw of pawns after castling

## Improvements

- Add more openings
- Transposition table (http://www.chessbin.com/post/Transposition-Table-and-Zobrist-Hashing, https://chessprogramming.wikispaces.com/Transposition+Table)
- Optimization: https://people.cs.clemson.edu/~dhouse/courses/405/papers/optimize.pdf

- Helper for p FPGN::to_string(move, (FPGN::SANType)1)

- Time management in UCI

## References

Chess Programs:
- http://www.bluefever.net/Chess/index.html

- https://www.chess.com/article/view/the-evaluation-of-material-imbalances-by-im-larry-kaufman
- https://chessprogramming.wikispaces.com/Kaufman+Test
- http://www.top-5000.nl/authors/rebel/chess840.htm#EVAL
- http://www.chessbin.com/post/Chess-Board-Evaluation
