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
    
    void addMove(Board &board, int from, int to, Piece piece, bool capture);
    void addMoves(Board &board, int from, Bitboard moves, Piece piece, bool capture);
};


