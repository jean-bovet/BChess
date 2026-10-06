//
//  FBoard.hpp
//  BChess
//
//  Created by Jean Bovet on 11/26/17.
//  Copyright © 2017 Jean Bovet. All rights reserved.
//

#pragma once

#include "Move.hpp"
#include "Bitboard.hpp"
#include "Types.hpp"

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
    BoardHash hash = 0;
    
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

    // The plies since the last pawn move or capture that were played on this board, which no earlier position can
    // follow into a repetition. It is -1 ("unknown") after a FEN, a reset or any edit of the squares: a FEN's
    // halfMoveClock can hold any value, so it cannot say how many positions the game really has behind it.
    // Not part of the position: it is not in the hash, the FEN or ChessState.
    int reversiblePlies = -1;
    
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
    
    void move(Move move);
    
    // Plays the move for the legality test of MoveList::addSingleMove, which only reads isCheck on the copy it
    // makes it on. It skips all the hash work, so the hash is left "to be computed" and nothing may rely on it.
    void moveForLegality(Move move);
    
    void move(Color color, Piece piece, Square from, Square to);
    
    Bitboard allPieces(Color color) const;
    
    // True when the en-passant square can be a capture target for `color`: it is on the right rank, the
    // target is empty and an opposing pawn stands behind it. Move generation and the hash both use this.
    bool isEnPassantTargetValid(Color color) const;
    Bitboard emptySquares();
    
    Bitboard getOccupancy();
    
    bool isAttacked(Square square, Color byColor);
    
    bool isCheck(Color color);
    
    BoardHash getHash();
    
    void setCastling(std::string castling) {
        whiteCanCastleKingSide = castling.find('K') != std::string::npos;
        whiteCanCastleQueenSide = castling.find('Q') != std::string::npos;
        blackCanCastleKingSide = castling.find('k') != std::string::npos;
        blackCanCastleQueenSide = castling.find('q') != std::string::npos;
        hash = 0; // Need to recompute it
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
    
private:
    // move() and moveForLegality() are one body: the rules cannot drift apart
    template<bool UpdateHash> void applyMove(Move move);
    template<bool UpdateHash> void movePieceOnBoard(Color color, Piece piece, Square from, Square to);
};

