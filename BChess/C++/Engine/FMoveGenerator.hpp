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

class FastMoveGenerator {
private:
    static bool magicInitialized;
    
public:
    FastMoveGenerator();
    
    void initPawnMoves();
    void initKingMoves();
    void initKnightMoves();
    
    MoveList generateMoves(Board board, Color color, int squareIndex = -1);
    void generatePawnsMoves(Board &board, Color color, MoveList &moveList, int squareIndex = -1);
    void generateKingsMoves(Board &board, Color color, MoveList &moveList, int squareIndex = -1);
    void generateKnightsMoves(Board &board, Color color, MoveList &moveList, int squareIndex = -1);
    void generateSlidingMoves(Board &board, Color color, Piece piece, MoveList &moveList, int squareIndex = -1);
};

