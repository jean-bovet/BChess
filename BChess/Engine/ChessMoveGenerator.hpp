//
//  FMoveGenerator.hpp
//  BChess
//
//  Created by Jean Bovet on 12/3/17.
//  Copyright © 2017 Jean Bovet. All rights reserved.
//

#pragma once

#include "MoveList.hpp"
#include "ChessBoard.hpp"
#include "Coordinate.hpp"

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

    static bool isValid(Move move) {
        return MOVE_ISVALID(move);
    }
    
    enum class Mode {
        allMoves,
        quiescenceMoveOnly,
        firstMoveOnly,
        moveCaptureAndDefenseMoves
    };
    
    static MoveList generateQuiescenceMoves(ChessBoard &board);
    static MoveList generateQuiescenceMoves(ChessBoard &board, Color color);

    static MoveList generateMoves(ChessBoard &board);
    static MoveList generateMoves(ChessBoard &board, Color color, Mode mode = Mode::allMoves, Square specificSquare = SquareUndefined);
    
    static void generateAttackMoves(ChessBoard &board, Color color, MoveList &moveList, Square fromSquare, Piece attackingPiece, Bitboard attackingSquares, Mode mode);
    
    static void generatePawnsMoves(ChessBoard &board, Color color, MoveList &moveList, Mode mode, Square specificSquare = SquareUndefined);
    static void generateKingsMoves(ChessBoard &board, Color color, MoveList &moveList, Mode mode, Square specificSquare = SquareUndefined);
    static void generateKnightsMoves(ChessBoard &board, Color color, MoveList &moveList, Mode mode, Square specificSquare = SquareUndefined);
    static void generateSlidingMoves(ChessBoard &board, Color color, Piece piece, MoveList &moveList, Mode mode, Square specificSquare = SquareUndefined);
};

