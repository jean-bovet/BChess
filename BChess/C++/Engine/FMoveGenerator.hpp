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
#include "FCoordinate.hpp"

// Without this, the C file won't be linked
extern "C" void initmagicmoves(void);

class ChessMoveGenerator {
private:
    static void initialize();
    
    static void initPawnMoves();
    static void initKingMoves();
    static void initKnightMoves();

public:        
    static MoveList generateMoves(Board board, Square specificSquare = SquareUndefined);
    
    static void generateAttackMoves(Board &board, MoveList &moveList, Square fromSquare, Piece attackingPiece, Bitboard attackingSquares);
    
    static void generatePawnsMoves(Board &board, MoveList &moveList, Square specificSquare = SquareUndefined);
    static void generateKingsMoves(Board &board, MoveList &moveList, Square specificSquare = SquareUndefined);
    static void generateKnightsMoves(Board &board, MoveList &moveList, Square specificSquare = SquareUndefined);
    static void generateSlidingMoves(Board &board, Piece piece, MoveList &moveList, Square specificSquare = SquareUndefined);
};

