//
//  FMoveGenerator.hpp
//  BChess
//
//  Created by Jean Bovet on 12/3/17.
//  Copyright © 2017 Jean Bovet. All rights reserved.
//

#pragma once

#include "FMoveList.hpp"
#include "ChessBoard.hpp"
#include "FCoordinate.hpp"

// Without this, the C file won't be linked
extern "C" void initmagicmoves(void);

class ChessMoveGenerator {
private:
    static void initPawnMoves();
    static void initKingMoves();
    static void initKnightMoves();

public:
    static void initialize();

    static void sortMoves(MoveList & moves);

    static MoveList generateMoves(ChessBoard board, bool qs = false, Square specificSquare = SquareUndefined);
    
    static void generateAttackMoves(ChessBoard &board, MoveList &moveList, Square fromSquare, Piece attackingPiece, Bitboard attackingSquares);
    
    static void generatePawnsMoves(ChessBoard &board, MoveList &moveList, bool qs, Square specificSquare = SquareUndefined);
    static void generateKingsMoves(ChessBoard &board, MoveList &moveList, bool qs, Square specificSquare = SquareUndefined);
    static void generateKnightsMoves(ChessBoard &board, MoveList &moveList, bool qs, Square specificSquare = SquareUndefined);
    static void generateSlidingMoves(ChessBoard &board, Piece piece, MoveList &moveList, bool qs, Square specificSquare = SquareUndefined);
};

