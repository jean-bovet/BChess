//
//  FMoveList.hpp
//  BChess
//
//  Created by Jean Bovet on 12/3/17.
//  Copyright © 2017 Jean Bovet. All rights reserved.
//

#pragma once

#include "FMove.hpp"
#include "FBitboard.hpp"
#include "MinMaxMoveList.hpp"

class ChessBoard;

struct ChessMoveList : MinMaxMoveList<Move> {
    std::string description();
        
    void addMove(ChessBoard &board, Move move);
    void addMoves(ChessBoard &board, Square from, Bitboard moves, Piece piece);
    void addCaptures(ChessBoard &board, Square from, Bitboard moves, Color attackingPieceColor, Piece attackingPiece, Color capturedPieceColor, Piece capturedPiece);
};



