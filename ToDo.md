#  BChess

## ToDo

- Ability for the UI to choose promotion
- Handle UCI move with promotion (for example h1b1q)

## Improvements

- Best line caching for iterative deepening
- Quiet move should not include check (use this position to see if the mat can be seen when doing shallow depth search: r3kb1r/pp2pQpp/n7/qNn1N3/8/P7/1PP2PPP/R1B1R1K1 b kq - 0 15)
- Transposition table (http://www.chessbin.com/post/Transposition-Table-and-Zobrist-Hashing, https://chessprogramming.wikispaces.com/Transposition+Table)

- Helper for p FPGN::to_string(move, (FPGN::SANType)1)

- Time management in UCI

## References

Chess Programs:
- http://www.bluefever.net/Chess/index.html

