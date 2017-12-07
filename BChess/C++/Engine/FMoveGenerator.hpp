//
//  FMoveGenerator.hpp
//  BChess
//
//  Created by Jean Bovet on 12/3/17.
//  Copyright © 2017 Jean Bovet. All rights reserved.
//

#pragma once

#include "FMoveList.hpp"
#include "FBoard.hpp"

// Without this, the C file won't be linked
extern "C" void initmagicmoves(void);

class MoveGenerator {
private:
    static void initPawnMoves();
    static void initKingMoves();
    static void initKnightMoves();

public:
    static void initialize();
        
    MoveList generateMoves(Board board, int squareIndex = -1);
    void generatePawnsMoves(Board &board, MoveList &moveList, int squareIndex = -1);
    void generateKingsMoves(Board &board, MoveList &moveList, int squareIndex = -1);
    void generateKnightsMoves(Board &board, MoveList &moveList, int squareIndex = -1);
    void generateSlidingMoves(Board &board, Piece piece, MoveList &moveList, int squareIndex = -1);
};

