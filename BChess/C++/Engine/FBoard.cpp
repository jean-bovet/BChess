//
//  FBoard.cpp
//  BChess
//
//  Created by Jean Bovet on 11/26/17.
//  Copyright © 2017 Jean Bovet. All rights reserved.
//

#include "FBoard.hpp"
#include <bitstring.h>
#include <iostream>
#include <cassert>
#include "magicmoves.h"

Bitboard PawnAttacks[2][64];

Bitboard KingMoves[64];
Bitboard KnightMoves[64];

/**
rank
    8
    7
    6
    5
    4
    3
    2
    1 a1 b1 c1 d1 e1 f1 g1 h1
      a  b  c  d  e  f  g  h  <- file
    a1 = 0
    h1 = 2^7 = 128
    h8 = 2^63
 */

inline static Bitboard BB(Bitboard userDefined) {
    Bitboard reversed = 0;
    for (int rank = 0; rank < 8; rank++) {
        for (int file = 0; file < 8; file++) {
            if (bb_test(userDefined, 7 - file, rank)) {
                bb_set(reversed, file, rank);
            }
        }
    }
    return reversed;
}

static Bitboard IWhiteKnights = BB(0b\
00000000\
00000000\
00000000\
00000000\
00000000\
00000000\
00000000\
01000010\
);

static Bitboard IBlackKnights = BB(0b\
01000010\
00000000\
00000000\
00000000\
00000000\
00000000\
00000000\
00000000\
);

static Bitboard IWhiteRooks = BB(0b\
00000000\
00000000\
00000000\
00000000\
00000000\
00000000\
00000000\
10000001\
);

static Bitboard IBlackRooks = BB(0b\
10000001\
00000000\
00000000\
00000000\
00000000\
00000000\
00000000\
00000000\
);

static Bitboard IWhiteBishops = BB(0b\
00000000\
00000000\
00000000\
00000000\
00000000\
00000000\
00000000\
00100100\
);

static Bitboard IBlackBishops = BB(0b\
00100100\
00000000\
00000000\
00000000\
00000000\
00000000\
00000000\
00000000\
);

static Bitboard IWhiteKing = BB(0b\
00000000\
00000000\
00000000\
00000000\
00000000\
00000000\
00000000\
00001000\
);

static Bitboard IBlackKing = BB(0b\
00001000\
00000000\
00000000\
00000000\
00000000\
00000000\
00000000\
00000000\
);

static Bitboard IWhiteQueen = BB(0b\
00000000\
00000000\
00000000\
00000000\
00000000\
00000000\
00000000\
00010000\
);

static Bitboard IBlackQueen = BB(0b\
00010000\
00000000\
00000000\
00000000\
00000000\
00000000\
00000000\
00000000\
);

static Bitboard IWhitePawns = BB(0b\
00000000\
00000000\
00000000\
00000000\
00000000\
00000000\
11111111\
00000000\
);

static Bitboard IBlackPawns = BB(0b\
00000000\
11111111\
00000000\
00000000\
00000000\
00000000\
00000000\
00000000\
);

#pragma mark -

Board::Board() {
    pieces[WHITE][PAWN] = IWhitePawns;
    pieces[WHITE][KING] = IWhiteKing;
    pieces[WHITE][QUEEN] = IWhiteQueen;
    pieces[WHITE][ROOK] = IWhiteRooks;
    pieces[WHITE][BISHOP] = IWhiteBishops;
    pieces[WHITE][KNIGHT] = IWhiteKnights;
    
    pieces[BLACK][PAWN] = IBlackPawns;
    pieces[BLACK][KING] = IBlackKing;
    pieces[BLACK][QUEEN] = IBlackQueen;
    pieces[BLACK][ROOK] = IBlackRooks;
    pieces[BLACK][BISHOP] = IBlackBishops;
    pieces[BLACK][KNIGHT] = IBlackKnights;
    
    occupancyDirty = true;
}

void Board::move(Move move) {
    if (color == BLACK) {
        fullMoveCount++;
    }

    halfMoveClock++;
    
    auto moveColor = MOVE_COLOR(move);
    auto movePiece = MOVE_PIECE(move);
    
    auto from = MOVE_FROM(move);
    auto to = MOVE_TO(move);
    
    Board::move(moveColor, movePiece, from, to);
    
    if (movePiece == KING) {
        if (moveColor == WHITE) {
            whiteCanCastleKingSide = whiteCanCastleQueenSide = false;
            
            if (from == e1 && to == g1) {
                // White castle king side, need to move the rook
                Board::move(moveColor, ROOK, h1, f1);
            }
            if (from == e1 && to == c1) {
                // White castle queen side, need to move the rook
                Board::move(moveColor, ROOK, a1, d1);
            }
        } else {
            blackCanCastleKingSide = blackCanCastleQueenSide = false;
            
            if (from == e8 && to == g8) {
                // Black castle king side, need to move the rook
                Board::move(moveColor, ROOK, h8, f8);
            }
            if (from == e8 && to == c8) {
                // Black castle queen side, need to move the rook
                Board::move(moveColor, ROOK, a8, d8);
            }
        }
    }

    // Reset halfmove clock if a pawn is moved
    if (movePiece == PAWN) {
        halfMoveClock = 0;
    }
    
    // First detect if the move is the "en-passant" move
    if (MOVE_IS_ENPASSANT(move)) {
        auto otherColor = INVERSE(moveColor);
        auto enPassantSquare = lsb(enPassant);
        // The pawn to remove by the "en-passant" move is actually below the pawn doing the "en-passant" move.
        if (moveColor == WHITE) {
            enPassantSquare -= 8;
        } else {
            enPassantSquare += 8;
        }
        
        bb_clear(pieces[otherColor][PAWN], enPassantSquare);
        bb_clear(pieces[otherColor][KNIGHT], enPassantSquare);
        bb_clear(pieces[otherColor][BISHOP], enPassantSquare);
        bb_clear(pieces[otherColor][ROOK], enPassantSquare);
        bb_clear(pieces[otherColor][QUEEN], enPassantSquare);
        bb_clear(pieces[otherColor][KING], enPassantSquare);
    }
    
    // Detect if a pawn moves two squares in order to enable
    // the "en-passant" move. Clear the enPassant bitboard
    // in case no en-passant is found.
    enPassant = 0;
    if (movePiece == PAWN) {
        int fromRank = rank_index(from);
        int toRank = rank_index(to);
        if (moveColor == WHITE && toRank - fromRank == 2) {
            bb_set(enPassant, from+8);
        } else if (moveColor == BLACK && fromRank - toRank == 2) {
            bb_set(enPassant, from-8);
        }
    }

    if (movePiece == ROOK) {
        if (moveColor == WHITE) {
            whiteCanCastleKingSide = whiteCanCastleQueenSide = false;
        } else {
            blackCanCastleKingSide = blackCanCastleQueenSide = false;
        }
    }
    
    auto otherColor = INVERSE(moveColor);
    bb_clear(pieces[otherColor][PAWN], to);
    bb_clear(pieces[otherColor][KNIGHT], to);
    bb_clear(pieces[otherColor][BISHOP], to);
    bb_clear(pieces[otherColor][ROOK], to);
    bb_clear(pieces[otherColor][QUEEN], to);
    bb_clear(pieces[otherColor][KING], to);

    if (MOVE_IS_CAPTURE(move)) {
        halfMoveClock = 0; // reset halfmove clock if capture is done
    }

    color = INVERSE(color);
}

Bitboard Board::getOccupancy() {
    if (occupancyDirty) {
        auto whitePieces = allPieces(Color::WHITE);
        auto blackPieces = allPieces(Color::BLACK);
        occupancy = whitePieces|blackPieces;
        occupancyDirty = false;
    }
    return occupancy;
}

void Board::move(Color color, Piece piece, int from, int to) {
    bb_clear(pieces[color][piece], from);
    bb_set(pieces[color][piece], to);
    occupancyDirty = true;
}

void Board::move(std::string from, std::string to) {
    auto fromIndex = squareIndexForName(from);
    auto toIndex = squareIndexForName(to);
    for (auto piece=0; piece<Piece::PCOUNT; piece++) {
        if (bb_test(pieces[color][piece], fromIndex)) {
            bool capture = bb_test(allPieces(INVERSE(color)), toIndex);
            Move m = createMove(fromIndex, toIndex, color, Piece(piece), capture, false); // TODO en passant
            move(m);
            break;
        }
    }
}

inline static char charForPiece(Color color, Piece piece) {
    auto white = color == WHITE;
    switch (piece) {
        case PAWN:
            return white ? 'P' : 'p';
        case ROOK:
            return white ? 'R' : 'r';
        case KNIGHT:
            return white ? 'N' : 'n';
        case BISHOP:
            return white ? 'B' : 'b';
        case QUEEN:
            return white ? 'Q' : 'q';
        case KING:
            return white ? 'K' : 'k';
        case PCOUNT:
            return '?';
    }
}

void Board::print() {
    for (int rank = 7; rank >= 0; rank--) {
        for (int file = 0; file < 8; file++) {
            char c = '.';
            
            for (auto color=0; color<Color::COUNT; color++) {
                for (auto piece=0; piece<Piece::PCOUNT; piece++) {
                    if (bb_test(pieces[color][piece], file, rank)) {
                        c = charForPiece((Color)color, (Piece)piece);
                    }
                }
            }
            
            std::cout << c;
        }
        std::cout << std::endl;
    }
    std::cout << std::endl;
}

Square Board::get(int file, int rank) {
    Square square;
    if (bb_test(getOccupancy(), file, rank)) {
        for (auto color=0; color<Color::COUNT; color++) {
            for (auto piece=0; piece<Piece::PCOUNT; piece++) {
                if (bb_test(pieces[color][piece], file, rank)) {
                    square.empty = false;
                    square.color = Color(color);
                    square.piece = Piece(piece);
                    return square;
                }
            }
        }
    } else {
        square.empty = true;
    }
    return square;
}

void Board::set(Square square, int file, int rank) {
    if (square.empty) {
        for (auto color=0; color<Color::COUNT; color++) {
            for (auto piece=0; piece<Piece::PCOUNT; piece++) {
                bb_clear(pieces[color][piece], file, rank);
            }
        }
    } else {
        bb_set(pieces[square.color][square.piece], file, rank);
    }
    occupancyDirty = true;
}

Bitboard Board::allPieces(Color color) {
    return pieces[color][PAWN]|
    pieces[color][ROOK]|
    pieces[color][KNIGHT]|
    pieces[color][BISHOP]|
    pieces[color][QUEEN]|
    pieces[color][KING];    
}

Bitboard Board::emptySquares() {
    return ~getOccupancy();
}

bool Board::isCheck(Color color) {
    // Locate the king
    auto kingBoard = pieces[color][Piece::KING];
    if (kingBoard == 0) {
        return false; // No king, can happen when testing
    }
    int kingSquare = lsb(kingBoard);
    
    auto otherColor = INVERSE(color);
    
    // Generate all the moves for a knight from the king position
    // and keep only the ones that are actually hitting
    // a black knight, meaning the king is attacked.
    auto moves = KnightMoves[kingSquare] & pieces[otherColor][Piece::KNIGHT];
    if (moves > 0) {
        return true;
    }
    
    // Same for bishop (and queen)
    auto rawBishopMoves = Bmagic(kingSquare, getOccupancy());
    auto bishopMoves = rawBishopMoves & (pieces[otherColor][Piece::BISHOP]|pieces[otherColor][Piece::QUEEN]);
    if (bishopMoves > 0) {
        return true;
    }

    // Same for rook (and queen)
    auto rawRookMoves = Rmagic(kingSquare, getOccupancy());
    auto rookMoves = rawRookMoves & (pieces[otherColor][Piece::ROOK]|pieces[otherColor][Piece::QUEEN]);
    if (rookMoves > 0) {
        return true;
    }
    
    // Pawns: we put a pawn of the opposite color at our king's location. That way, we can
    // determine the attacks that a pawn from the opposite color would do.
    auto pawnAttacks = PawnAttacks[color][kingSquare] & pieces[otherColor][Piece::PAWN];
    if (pawnAttacks > 0) {
        return true;
    }

    // King
    auto kingMoves = KingMoves[kingSquare] & pieces[otherColor][Piece::KING];
    if (kingMoves > 0) {
        return true;
    }

    return false;
}


