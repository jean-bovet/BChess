//
//  FMove.hpp
//  BChess
//
//  Created by Jean Bovet on 12/3/17.
//  Copyright © 2017 Jean Bovet. All rights reserved.
//

#pragma once

#include "FColor.hpp"
#include "FPiece.hpp"

#include <string>

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

inline static int squareIndexForName(std::string name) {
    for (int i=0; i<64; i++) {
        if (SquareNames[i] == name) {
            return i;
        }
    }
    return -1;
}

// A move needs 32 bits to be stored
// bit 0-5: destination square (from 0 to 63)
// bit 6-11: origin square (from 0 to 63)
// bit 12: 1=BLACK, 0=WHITE
// bit 13-15: 3 bits for PIECE (from 0 to 6)
// bit 16: 0=move, 1=capture
typedef uint32_t Move;

inline static Move createMove(int from, int to, Color color, Piece piece, bool capture) {
    Move m = from | to << 6 | color << 12 | piece << 13;
    if (capture) {
        m |= 1UL << 16;
    }
    return m;
}

inline static bool MOVE_ISVALID(Move move) {
    return move != 0;
}

inline static bool MOVE_IS_CAPTURE(Move move) {
    uint32_t test = move & (1UL << 16);
    return test > 0;
}

inline static Color MOVE_COLOR(Move move) {
    uint16_t test = move & (1 << 12);
    return test > 0 ? BLACK : WHITE;
}

inline static Piece MOVE_PIECE(Move move) {
    uint8_t test = (move >> 13) & 7;
    return Piece(test);
}

inline static uint8_t MOVE_FROM(Move move) {
    uint8_t from = move & 63;
    return from;
}

inline static uint8_t MOVE_TO(Move move) {
    uint8_t to = (move >> 6) & 63;
    return to;
}

inline static std::string MOVE_DESCRIPTION(Move move) {
    auto fromSquare = SquareNames[MOVE_FROM(move)];
    auto toSquare = SquareNames[MOVE_TO(move)];
    return fromSquare+toSquare;
}
