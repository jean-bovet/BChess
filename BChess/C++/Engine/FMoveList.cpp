//
//  FMoveList.cpp
//  BChess
//
//  Created by Jean Bovet on 12/3/17.
//  Copyright © 2017 Jean Bovet. All rights reserved.
//

#include "FMoveList.hpp"

void MoveList::addMove(Board &board, Square from, Square to, Piece piece, bool capture, bool enPassant) {
    Move move = createMove(from, to, board.color, piece, capture, enPassant);
    Board validBoard = board;
    validBoard.move(move);
    // Note: make sure the move that was just played doesn't make
    // it's king in check (use board.color which refers to the move's color).
    if (!validBoard.isCheck(board.color)) {
        moves[moveCount] = move;
        moveCount++;
    }
}

void MoveList::addMoves(Board &board, Square from, Bitboard moves, Piece piece, bool capture, bool enPassant) {
    while (moves > 0) {
        Square to = lsb(moves);
        bb_clear(moves, to);
        
        addMove(board, from, to, piece, capture, enPassant);
    }
}

