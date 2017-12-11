#  BChess

Bug:
- cannot select square to do castle!
- doesn't seem to do pawn promotion with black
- doesn't generate castle moves
- UI: indication of mate or draw
- for UI: generate all the moves for the current position and then AND it with the current selection to ensure it can move (this happens if the king is in check, you cannot move a piece that's not going to eliminate the check)

ToDo

- Time management
- Check how the best line is used (or maybe think about re-ordering the moves)
