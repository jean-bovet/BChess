//
//  FMoveGenerator.hpp
//  BChess
//
//  Created by Jean Bovet on 12/3/17.
//  Copyright © 2017 Jean Bovet. All rights reserved.
//

#pragma once

#include "ChessMoveList.hpp"
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

    static void sortMoves(ChessMoveList & moves);

    static bool isValid(Move move) {
        return MOVE_ISVALID(move);
    }
    
    enum class Mode {
        allMoves,
        quiescenceMoveOnly,
        firstMoveOnly
    };
    
    static ChessMoveList generateQuiescenceMoves(ChessBoard &board);
    static ChessMoveList generateQuiescenceMoves(ChessBoard &board, Color color);

    static ChessMoveList generateMoves(ChessBoard &board);
    static ChessMoveList generateMoves(ChessBoard &board, Color color, Mode mode = Mode::allMoves, Square specificSquare = SquareUndefined);
    
    static void generateAttackMoves(ChessBoard &board, Color color, ChessMoveList &moveList, Square fromSquare, Piece attackingPiece, Bitboard attackingSquares, Mode mode);
    
    static void generatePawnsMoves(ChessBoard &board, Color color, ChessMoveList &moveList, Mode mode, Square specificSquare = SquareUndefined);
    static void generateKingsMoves(ChessBoard &board, Color color, ChessMoveList &moveList, Mode mode, Square specificSquare = SquareUndefined);
    static void generateKnightsMoves(ChessBoard &board, Color color, ChessMoveList &moveList, Mode mode, Square specificSquare = SquareUndefined);
    static void generateSlidingMoves(ChessBoard &board, Color color, Piece piece, ChessMoveList &moveList, Mode mode, Square specificSquare = SquareUndefined);
};

