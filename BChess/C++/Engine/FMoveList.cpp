//
//  FMoveList.cpp
//  BChess
//
//  Created by Jean Bovet on 12/3/17.
//  Copyright © 2017 Jean Bovet. All rights reserved.
//

#include "FMoveList.hpp"
#include "FBoard.hpp"
#include "FPGN.hpp"

std::string MoveList::description() {
    std::string text = "";
    for (auto move : moves) {
        if (text.length() > 0) {
            text += " ";
        }
        text += FPGN::to_string(move);
    }
    return text;
}

void MoveList::addMove(Move move) {
    moves.push_back(move);
}

void MoveList::addMoves(MoveList moves) {
    MoveList::moves.insert(MoveList::moves.end(), moves.moves.begin(), moves.moves.end());
}

void MoveList::addMove(Board &board, Move move) {
    Board validBoard = board;
    validBoard.move(move);
    // Note: make sure the move that was just played doesn't make
    // it's king in check (use board.color which refers to the move's color).
    if (!validBoard.isCheck(board.color)) {
        addMove(move);
    }
}

void MoveList::addMoves(Board &board, Square from, Bitboard moves, Piece piece) {
    while (moves > 0) {
        Square to = lsb(moves);
        bb_clear(moves, to);
        
        addMove(board, createMove(from, to, board.color, piece));
    }
}

void MoveList::addCaptures(Board &board, Square from, Bitboard moves, Piece attackingPiece, Piece capturedPiece) {
    while (moves > 0) {
        Square to = lsb(moves);
        bb_clear(moves, to);
        
        addMove(board, createCapture(from, to, board.color, attackingPiece, capturedPiece));
    }
}

