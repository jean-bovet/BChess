//
//  FMoveList.cpp
//  BChess
//
//  Created by Jean Bovet on 12/3/17.
//  Copyright © 2017 Jean Bovet. All rights reserved.
//

#include "FMoveList.hpp"
#include "ChessBoard.hpp"
#include "FPGN.hpp"

std::string MoveList::description() {
    std::string text = "";
    for (int index=0; index<count; index++) {
        auto move = _moves[index];
        if (text.length() > 0) {
            text += " ";
        }
        text += FPGN::to_string(move);
    }
    return text;
}

void MoveList::addMove(Move move) {
    _moves[count] = move;
    count++;
}

void MoveList::insertMove(int index, Move move) {
    _moves[index] = move;
    count = std::max(index + 1, count);
}

void MoveList::addMoves(MoveList moves) {
    for (int index=0; index<moves.count; index++) {
        addMove(moves._moves[index]);
    }
}

void MoveList::addMove(ChessBoard &board, Move move) {
    ChessBoard validBoard = board;
    validBoard.move(move);
    // Note: make sure the move that was just played doesn't make
    // it's king in check (use board.color which refers to the move's color).
    if (!validBoard.isCheck(board.color)) {
        addMove(move);
    }
}

void MoveList::addMoves(ChessBoard &board, Square from, Bitboard moves, Piece piece) {
    while (moves > 0) {
        Square to = lsb(moves);
        bb_clear(moves, to);
        
        addMove(board, createMove(from, to, board.color, piece));
    }
}

void MoveList::addCaptures(ChessBoard &board, Square from, Bitboard moves, Piece attackingPiece, Piece capturedPiece) {
    while (moves > 0) {
        Square to = lsb(moves);
        bb_clear(moves, to);
        
        addMove(board, createCapture(from, to, board.color, attackingPiece, capturedPiece));
    }
}

