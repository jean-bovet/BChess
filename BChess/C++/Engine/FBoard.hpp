//
//  FBoard.hpp
//  BChess
//
//  Created by Jean Bovet on 11/26/17.
//  Copyright © 2017 Jean Bovet. All rights reserved.
//

#pragma once

#include "FMove.hpp"

#include <stdio.h>
#include <cstdint>
#include <string>
#include <iostream>
#include <cassert>

inline static int square_index(int file, int rank) {
    return 8 * rank + file;
}

inline static int file_index(int square) {
    return square & 7;
}

inline static int rank_index(int square) {
    return square >> 3;
}

#pragma mark - Bitboard

typedef uint64_t Bitboard;

inline static bool bb_test(Bitboard bitboard, int square) {
    uint64_t test = bitboard & (1UL << square);
    return test > 0;
}

inline static bool bb_test(Bitboard bitboard, int file, int rank) {
    return bb_test(bitboard, square_index(file, rank));
}

inline static void bb_clear(Bitboard &bitboard, int square) {
    bitboard &= ~(1UL << square);
}

inline static void bb_clear(Bitboard &bitboard, int file, int rank) {
    bb_clear(bitboard, square_index(file, rank));
}

inline static void bb_set(Bitboard &bitboard, int square) {
    bitboard |= 1UL << square;
}

inline static void bb_set(Bitboard &bitboard, int file, int rank) {
    if (file >= 0 && file <= 7 && rank >= 0 && rank <= 7) {
        bb_set(bitboard, square_index(file, rank));
    }
}

inline static void bb_print(Bitboard bitboard) {
    for (int rank = 7; rank >= 0; rank--) {
        for (int file = 0; file < 8; file++) {
            std::cout << (bb_test(bitboard, file, rank) > 0  ? "X" : ".");
        }
        std::cout << std::endl;
    }
    std::cout << std::endl;
}

inline static int lsb(Bitboard bb) {
    assert(bb > 0);
    return __builtin_ctzll(bb);
}

inline static int bb_count(Bitboard bb) {
    return __builtin_popcountl(bb);
}

extern Bitboard PawnAttacks[2][64];
extern Bitboard PawnMoves[2][64];

extern Bitboard KingMoves[64];
extern Bitboard KnightMoves[64];

enum enumSquare {
    a1, b1, c1, d1, e1, f1, g1, h1,
    a2, b2, c2, d2, e2, f2, g2, h2,
    a3, b3, c3, d3, e3, f3, g3, h3,
    a4, b4, c4, d4, e4, f4, g4, h4,
    a5, b5, c5, d5, e5, f5, g5, h5,
    a6, b6, c6, d6, e6, f6, g6, h6,
    a7, b7, c7, d7, e7, f7, g7, h7,
    a8, b8, c8, d8, e8, f8, g8, h8
};

struct Square {
    bool empty;
    Color color;
    Piece piece;
};

struct Board {
    Color color = Color::WHITE;
    Bitboard pieces[Color::COUNT][Piece::PCOUNT] = { };
    
    // Fullmove number: The number of the full move. It starts at 1, and is incremented after Black's move
    int fullMoveCount = 1;

    Board();
    
    void clear() {
        memset(pieces, 0, sizeof(pieces));
    }
    
    Square get(int file, int rank);
    void set(Square square, int file, int rank);
    
    void move(Move move);
    void move(std::string from, std::string to, Color color);
    
    Bitboard allPieces(Color color);
    Bitboard occupancy();
    Bitboard emptySquares();
    
    bool isCheck(Color color);
    
    void print();
};

