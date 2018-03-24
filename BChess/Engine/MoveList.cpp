//
//  FMoveList.cpp
//  BChess
//
//  Created by Jean Bovet on 12/3/17.
//  Copyright © 2017 Jean Bovet. All rights reserved.
//

#include "MoveList.hpp"
#include "ChessBoard.hpp"
#include "FPGN.hpp"

std::string MoveList::description() {
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

void MoveList::addSingleMove(ChessBoard &board, Move move) {
    ChessBoard validBoard = board;
    validBoard.move(move);
    // Note: make sure the move that was just played doesn't make it's king in check.
    if (!validBoard.isCheck(MOVE_COLOR(move))) {
        // Determine if the move makes the king of the opposite side in check.
        // This is used to know which moves to use during quiescence search,
        // as a check move is not considered a quiet move.
        // TODO: careful, we cannot just use check move in quiescence search just like that.
        // Seems that we need to read more about when we can use the stand_pat score.
        // See http://www.talkchess.com/forum/viewtopic.php?topic_view=threads&p=681015&t=60962
        //        if (validBoard.isCheck(validBoard.color)) {
        //            SET_MOVE_IS_CHECK(move);
        //        }
        
        // Add the valid move to the list
        push(move);
    }
}

void MoveList::addPromotionMove(ChessBoard &board, Move move, Piece promotedPiece) {
    SET_MOVE_PROMOTION_PIECE(move, promotedPiece);
    addSingleMove(board, move);
}

void MoveList::addMove(ChessBoard &board, Move move) {
    // Handle any pawn promotion by generating the promoted moves
    if (MOVE_PIECE(move) == PAWN) {
        auto toRank = RankFrom(MOVE_TO(move));
        auto whitePromotion = MOVE_COLOR(move) == WHITE && toRank == 7;
        auto blackPromotion = MOVE_COLOR(move) == BLACK && toRank == 0;
        if (whitePromotion || blackPromotion) {
            addPromotionMove(board, move, QUEEN);
            addPromotionMove(board, move, ROOK);
            addPromotionMove(board, move, BISHOP);
            addPromotionMove(board, move, KNIGHT);
        } else {
            addSingleMove(board, move);
        }
    } else {
        addSingleMove(board, move);
    }
}

void MoveList::addMoves(ChessBoard &board, Square from, Bitboard moves, Piece piece) {
    while (moves > 0) {
        Square to = lsb(moves);
        bb_clear(moves, to);
        
        addMove(board, createMove(from, to, board.color, piece));
    }
}

void MoveList::addCaptures(ChessBoard &board, Square from, Bitboard moves, Color attackingPieceColor, Piece attackingPiece, Color capturedPieceColor, Piece capturedPiece) {
    while (moves > 0) {
        Square to = lsb(moves);
        bb_clear(moves, to);
        
        addMove(board, createCapture(from, to, attackingPieceColor, attackingPiece, capturedPieceColor, capturedPiece));
    }
}
