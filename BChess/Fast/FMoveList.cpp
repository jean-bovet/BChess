//
//  FMoveList.cpp
//  BChess
//
//  Created by Jean Bovet on 12/3/17.
//  Copyright © 2017 Jean Bovet. All rights reserved.
//

#include "FMoveList.hpp"

void MoveList::addMove(Board &board, int from, int to, Color color, Piece piece) {
    Move move = createMove(from, to, color, piece);
    Board validBoard = board;
    validBoard.move(move);
    if (!validBoard.isCheck(color)) {
        moves[moveCount] = move;
        moveCount++;
    }
}

void MoveList::addMoves(Board &board, int from, Bitboard moves, Color color, Piece piece) {
    while (moves > 0) {
        int to = lsb(moves);
        bb_clear(moves, to);
        
        addMove(board, from, to, color, piece);
    }
}

