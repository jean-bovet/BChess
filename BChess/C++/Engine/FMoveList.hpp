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
#include <vector>

const int MAX_MOVES = 256;

class Board;

struct MoveList {
    std::vector<Move> moves;
    
    void addMove(Move move);
    void addMove(Board &board, Move move);
    void addMoves(Board &board, Square from, Bitboard moves, Piece piece);
    void addCaptures(Board &board, Square from, Bitboard moves, Piece attackingPiece, Piece capturedPiece);
};


