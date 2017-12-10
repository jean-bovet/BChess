//
//  FCoordinate.hpp
//  BChess
//
//  Created by Jean Bovet on 12/9/17.
//  Copyright © 2017 Jean Bovet. All rights reserved.
//

#pragma once

#include <string>

typedef uint8_t Square;
typedef uint8_t File;
typedef uint8_t Rank;

#define SquareUndefined UINT8_MAX

inline static Square SquareFrom(File file, Rank rank) {
    return 8 * rank + file;
}

inline static File FileFrom(Square square) {
    return square & 7;
}

inline static Rank RankFrom(int square) {
    return (Rank)(square >> 3);
}

static std::string SquareNames[64] = {
    "a1", "b1", "c1", "d1", "e1", "f1", "g1", "h1",
    "a2", "b2", "c2", "d2", "e2", "f2", "g2", "h2",
    "a3", "b3", "c3", "d3", "e3", "f3", "g3", "h3",
    "a4", "b4", "c4", "d4", "e4", "f4", "g4", "h4",
    "a5", "b5", "c5", "d5", "e5", "f5", "g5", "h5",
    "a6", "b6", "c6", "d6", "e6", "f6", "g6", "h6",
    "a7", "b7", "c7", "d7", "e7", "f7", "g7", "h7",
    "a8", "b8", "c8", "d8", "e8", "f8", "g8", "h8",
};

inline static Square squareForName(std::string name) {
    for (Square i=0; i<64; i++) {
        if (SquareNames[i] == name) {
            return i;
        }
    }
    return SquareUndefined;
}

enum SquareLiteral {
    a1, b1, c1, d1, e1, f1, g1, h1,
    a2, b2, c2, d2, e2, f2, g2, h2,
    a3, b3, c3, d3, e3, f3, g3, h3,
    a4, b4, c4, d4, e4, f4, g4, h4,
    a5, b5, c5, d5, e5, f5, g5, h5,
    a6, b6, c6, d6, e6, f6, g6, h6,
    a7, b7, c7, d7, e7, f7, g7, h7,
    a8, b8, c8, d8, e8, f8, g8, h8
};

