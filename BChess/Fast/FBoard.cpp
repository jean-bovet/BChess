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
Bitboard PawnMoves[2][64];

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
    pieces[Color::WHITE][Piece::PAWN] = IWhitePawns;
    pieces[Color::WHITE][Piece::KING] = IWhiteKing;
    pieces[Color::WHITE][Piece::QUEEN] = IWhiteQueen;
    pieces[Color::WHITE][Piece::ROOK] = IWhiteRooks;
    pieces[Color::WHITE][Piece::BISHOP] = IWhiteBishops;
    pieces[Color::WHITE][Piece::KNIGHT] = IWhiteKnights;
    
    pieces[Color::BLACK][Piece::PAWN] = IBlackPawns;
    pieces[Color::BLACK][Piece::KING] = IBlackKing;
    pieces[Color::BLACK][Piece::QUEEN] = IBlackQueen;
    pieces[Color::BLACK][Piece::ROOK] = IBlackRooks;
    pieces[Color::BLACK][Piece::BISHOP] = IBlackBishops;
    pieces[Color::BLACK][Piece::KNIGHT] = IBlackKnights;
}

void Board::move(Move move) {
    if (color == BLACK) {
        fullMoveCount += 1;
    }

    bb_clear(pieces[move.color][move.piece], move.from);
    bb_set(pieces[move.color][move.piece], move.to);
    
    // TODO optimize
    for (auto piece=0; piece<Piece::PCOUNT; piece++) {
        bb_clear(pieces[INVERSE(move.color)][piece], move.to);
    }

    color = INVERSE(color);
}

void Board::move(std::string from, std::string to, Color color) {
    Move m;
    m.from = squareIndexForName(from);
    m.to = squareIndexForName(to);
    m.color = color;
    
    for (auto piece=0; piece<Piece::PCOUNT; piece++) {
        if (bb_test(pieces[color][piece], m.from)) {
            m.piece = Piece(piece);
            break;
        }
    }

    move(m);
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
    if (bb_test(occupancy(), file, rank)) {
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
}

Bitboard Board::allPieces(Color color) {
    Bitboard all = 0;
    for (auto pieces : pieces[color]) {
        all |= pieces;
    }
    return all;
}

Bitboard Board::occupancy() {
    auto whitePieces = allPieces(Color::WHITE);
    auto blackPieces = allPieces(Color::BLACK);
    return whitePieces|blackPieces;
}

Bitboard Board::emptySquares() {
    return ~occupancy();
}

bool Board::isCheck(Color color) {
    // Locate the king
    auto kingBoard = pieces[color][Piece::KING];
    if (kingBoard == 0) return false; // No king, can happen when testing    
    int kingSquare = lsb(kingBoard);
    
    auto otherColor = INVERSE(color);
//    auto blackPieces = allPieces(INVERSE(color));
    
    // Generate all the moves for a knight from the king position
    // and keep only the ones that are actually hitting
    // a black knight, meaning the king is attacked.
    auto moves = KnightMoves[kingSquare] & pieces[otherColor][Piece::KNIGHT];
    if (moves > 0) {
        return true;
    }
    
    // Same for bishop (and queen)
    auto rawBishopMoves = Bmagic(kingSquare, occupancy());
    auto bishopMoves = rawBishopMoves & (pieces[otherColor][Piece::BISHOP]|pieces[otherColor][Piece::QUEEN]);
    if (bishopMoves > 0) {
        return true;
    }

    // Same for rook (and queen)
    auto rawRookMoves = Rmagic(kingSquare, occupancy());
    auto rookMoves = rawRookMoves & (pieces[otherColor][Piece::ROOK]|pieces[otherColor][Piece::QUEEN]);
    if (rookMoves > 0) {
        return true;
    }
    
    // TODO: king, pawns
    // Pawns: we put a pawn of the opposite color at our king's location. That way, we can
    // determine the attacks that a pawn from the opposite color would do.
    auto pawnAttacks = PawnAttacks[color][kingSquare] & pieces[otherColor][Piece::PAWN];
    if (pawnAttacks > 0) {
        return true;
    }

    return false;
}


