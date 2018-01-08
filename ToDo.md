#  BChess

## ToDo

- Ensure that when a Game is copied, the history is also copied, not just referenced because it will get messed up (see FEngineInfo)
- Better handling of openings when a FEN is passed (and the board is not in the expected state for the opening)
- Handle UCI move with promotion (for example h1b1q)
- Add 3 fold repetition rule
- Add 50 moves rule
- Add heuristic to add bonus when king is safely behind its raw of pawns after castling

## Improvements

- Add more openings
- Transposition table (http://www.chessbin.com/post/Transposition-Table-and-Zobrist-Hashing, https://chessprogramming.wikispaces.com/Transposition+Table)

- Helper for p FPGN::to_string(move, (FPGN::SANType)1)

- Time management in UCI

## References

Chess Programs:
- http://www.bluefever.net/Chess/index.html

