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

const int MAX_MOVES = 256;

class ChessBoard;

struct MoveList {
    Move moves[MAX_MOVES];
    int count = 0;
    
    std::string description();
    
    Move firstMove();
    
    void addMove(Move move);
    void insertMove(int index, Move move);
    
    void addMoves(MoveList moves);
    void addMove(ChessBoard &board, Move move);
    void addMoves(ChessBoard &board, Square from, Bitboard moves, Piece piece);
    void addCaptures(ChessBoard &board, Square from, Bitboard moves, Piece attackingPiece, Piece capturedPiece);
};


