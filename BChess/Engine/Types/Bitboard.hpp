//
//  FBitboard.hpp
//  BChess
//
//  Created by Jean Bovet on 12/9/17.
//  Copyright © 2017 Jean Bovet. All rights reserved.
//

#pragma once

#include "Coordinate.hpp"

#include <cstdint>
#include <iostream>
#include <cassert>

typedef uint64_t Bitboard;

inline static bool bb_test(Bitboard bitboard, Square square) {
    uint64_t test = bitboard & (1UL << square);
    return test > 0;
}

inline static bool bb_test(Bitboard bitboard, File file, Rank rank) {
    return bb_test(bitboard, SquareFrom(file, rank));
}

inline static void bb_clear(Bitboard &bitboard, Square square) {
    bitboard &= ~(1UL << square);
}

inline static void bb_clear(Bitboard &bitboard, File file, Rank rank) {
    bb_clear(bitboard, SquareFrom(file, rank));
}

inline static void bb_set(Bitboard &bitboard, Square square) {
    bitboard |= 1UL << square;
}

inline static void bb_set(Bitboard &bitboard, File file, Rank rank) {
    if (file >= 0 && file <= 7 && rank >= 0 && rank <= 7) {
        bb_set(bitboard, SquareFrom(file, rank));
    }
}

inline static void bb_print(Bitboard bitboard) {
    for (Rank rank = 7; rank >= 0; rank--) {
        for (File file = 0; file < 8; file++) {
            std::cout << (bb_test(bitboard, file, rank) > 0  ? "X" : ".");
        }
        std::cout << std::endl;
    }
    std::cout << std::endl;
}

inline static Square lsb(Bitboard bb) {
    assert(bb > 0);
    return (Square)__builtin_ctzll(bb);
}

inline static int bb_count(Bitboard bb) {
    return __builtin_popcountl(bb);
}

