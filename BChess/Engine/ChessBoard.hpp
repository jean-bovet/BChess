//
//  FBoard.hpp
//  BChess
//
//  Created by Jean Bovet on 11/26/17.
//  Copyright © 2017 Jean Bovet. All rights reserved.
//

#pragma once

#include "FMove.hpp"
#include "FBitboard.hpp"

#include <stdio.h>
#include <string>

extern Bitboard PawnAttacks[2][64];
extern Bitboard KingMoves[64];
extern Bitboard KnightMoves[64];

struct BoardSquare {
    bool empty;
    Color color;
    Piece piece;
};

struct ChessBoard {
private:
    Bitboard occupancy = 0;

public:
    Color color = WHITE;
    
    bool occupancyDirty = false;
    
    Bitboard pieces[COUNT][PCOUNT] = { };
    
    // Bitboard representing the en-passant
    // square (the one where the opposing pawn
    // can move to) for the last move.
    // Or 0 if no en-passant available.
    Bitboard enPassant = 0;
    
    // Halfmove clock: This is the number of halfmoves since the last capture or pawn advance. This is used to determine if a draw can be claimed under the fifty-move rule.
    int halfMoveClock = 0;

    // Fullmove number: The number of the full move. It starts at 1, and is incremented after Black's move
    int fullMoveCount = 1;

    // Castling availability (KQkq)
    bool whiteCanCastleKingSide = true;
    bool whiteCanCastleQueenSide = true;
    bool blackCanCastleKingSide = true;
    bool blackCanCastleQueenSide = true;
    
    ChessBoard();
    
    void reset();
    
    void clear();
    
    BoardSquare get(File file, Rank rank);
    void set(BoardSquare square, File file, Rank rank);
    
    Move getMove(std::string from, std::string to);

    void move(Move move);
    void move(Color color, Piece piece, Square from, Square to);
    
    Bitboard allPieces(Color color);
    Bitboard emptySquares();
    
    Bitboard getOccupancy();
    
    bool isAttacked(Square square, Color byColor);
    
    bool isCheck(Color color);
        
    void setCastling(std::string castling) {
        whiteCanCastleKingSide = castling.find('K') != std::string::npos;
        whiteCanCastleQueenSide = castling.find('Q') != std::string::npos;
        blackCanCastleKingSide = castling.find('k') != std::string::npos;
        blackCanCastleQueenSide = castling.find('q') != std::string::npos;
    }
    
    std::string getCastling() {
        std::string castling = "";
        if (whiteCanCastleKingSide) {
            castling += "K";
        }
        if (whiteCanCastleQueenSide) {
            castling += "Q";
        }
        if (blackCanCastleKingSide) {
            castling += "k";
        }
        if (blackCanCastleQueenSide) {
            castling += "q";
        }
        if (castling.size() == 0) {
            castling = "-";
        }
        return castling;
    }
    
    void print();
};

