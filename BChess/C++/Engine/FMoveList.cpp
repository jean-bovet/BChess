//
//  FMoveList.cpp
//  BChess
//
//  Created by Jean Bovet on 12/3/17.
//  Copyright © 2017 Jean Bovet. All rights reserved.
//

#include "FMoveList.hpp"

void MoveList::addMove(Board &board, Move move) {
    Board validBoard = board;
    validBoard.move(move);
    // Note: make sure the move that was just played doesn't make
    // it's king in check (use board.color which refers to the move's color).
    if (!validBoard.isCheck(board.color)) {
        moves[moveCount] = move;
        moveCount++;
    }
}

void MoveList::addMoves(Board &board, Square from, Bitboard moves, Piece piece) {
    while (moves > 0) {
        Square to = lsb(moves);
        bb_clear(moves, to);
        
        addMove(board, createMove(from, to, board.color, piece));
    }
}

void MoveList::addCaptures(Board &board, Square from, Bitboard moves, Piece piece) {
    while (moves > 0) {
        Square to = lsb(moves);
        bb_clear(moves, to);
        
        addMove(board, createCapture(from, to, board.color, piece));
    }
}

