//
//  FMoveList.hpp
//  BChess
//
//  Created by Jean Bovet on 12/3/17.
//  Copyright © 2017 Jean Bovet. All rights reserved.
//

#pragma once

#include "FMove.hpp"
#include "FBoard.hpp"

const int MAX_MOVES = 256;

struct MoveList {
    Move moves[MAX_MOVES];
    int moveCount = 0;
    
    void addMove(Board &board, Move move);
    void addMoves(Board &board, Square from, Bitboard moves, Piece piece);
    void addCaptures(Board &board, Square from, Bitboard moves, Piece piece);
};


