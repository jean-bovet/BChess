//
//  FMoveList.cpp
//  BChess
//
//  Created by Jean Bovet on 12/3/17.
//  Copyright © 2017 Jean Bovet. All rights reserved.
//

#include "ChessMoveList.hpp"
#include "ChessBoard.hpp"
#include "FPGN.hpp"

std::string ChessMoveList::description() {
    std::string text = "";
    for (int index=0; index<count; index++) {
        auto move = moves[index];
        if (text.length() > 0) {
            text += " ";
        }
        text += FPGN::to_string(move);
    }
    return text;
}

void ChessMoveList::addMove(ChessBoard &board, Move move) {
    if (legalOnly) {
        ChessBoard validBoard = board;
        validBoard.move(move);
        // Note: make sure the move that was just played doesn't make it's king in check.
        if (!validBoard.isCheck(MOVE_COLOR(move))) {
            // Determine if the move makes the king of the opposite side in check.
            // This is used to know which moves to use during quiescence search,
            // as a check move is not considered a quiet move.
            if (validBoard.isCheck(validBoard.color)) {
                SET_MOVE_IS_CHECK(move);
            }
            
            // Add the valid move to the list
            push(move);
        }
        return;
    }
    
    if (MOVE_CAPTURED_PIECE(move) == KING) {
        // If a move is able to capture a king, this means that the
        // position is invalid and the move that lead to this position
        // is illegal. Report that.
        illegal = true;
    } else {
        push(move);
    }
}

void ChessMoveList::addMoves(ChessBoard &board, Square from, Bitboard moves, Piece piece) {
    while (moves > 0) {
        Square to = lsb(moves);
        bb_clear(moves, to);
        
        addMove(board, createMove(from, to, board.color, piece));
        if (illegal) return;
    }
}

void ChessMoveList::addCaptures(ChessBoard &board, Square from, Bitboard moves, Piece attackingPiece, Piece capturedPiece) {
    while (moves > 0) {
        Square to = lsb(moves);
        bb_clear(moves, to);

        addMove(board, createCapture(from, to, board.color, attackingPiece, capturedPiece));
        if (illegal) return;
    }
}

