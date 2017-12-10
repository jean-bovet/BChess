//
//  FMoveList.cpp
//  BChess
//
//  Created by Jean Bovet on 12/3/17.
//  Copyright © 2017 Jean Bovet. All rights reserved.
//

#include "FMoveList.hpp"

void MoveList::addMove(Board &board, int from, int to, Piece piece, bool capture) {
    Move move = createMove(from, to, board.color, piece, capture);
    Board validBoard = board;
    validBoard.move(move);
    // Note: make sure the move that was just played doesn't make
    // it's king in check (use board.color which refers to the move's color).
    if (!validBoard.isCheck(board.color)) {
        moves[moveCount] = move;
        moveCount++;
    }
}

void MoveList::addMoves(Board &board, int from, Bitboard moves, Piece piece, bool capture) {
    while (moves > 0) {
        int to = lsb(moves);
        bb_clear(moves, to);
        
        addMove(board, from, to, piece, capture);
    }
}

