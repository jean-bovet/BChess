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
#include "FCoordinate.hpp"

#include <string>

// A move needs 32 bits to be stored
// bit 0-5: destination square (from 0 to 63)
// bit 6-11: origin square (from 0 to 63)
// bit 12: 1=BLACK, 0=WHITE
// bit 13-15: 3 bits for PIECE (from 0 to 6)
// bit 16: 0=move, 1=capture
// bit 17: 1=en passant, 0 otherwise
typedef uint32_t Move;

inline static Move createMove(Square from, Square to, Color color, Piece piece, bool capture, bool enPassant) {
    Move m = (Move)(from | to << 6 | color << 12 | piece << 13);
    if (capture) {
        m |= 1UL << 16;
    }
    if (enPassant) {
        m |= 1UL << 17;
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

inline static bool MOVE_IS_ENPASSANT(Move move) {
    uint32_t test = move & (1UL << 17);
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

inline static Square MOVE_FROM(Move move) {
    Square from = move & 63;
    return from;
}

inline static Square MOVE_TO(Move move) {
    Square to = (move >> 6) & 63;
    return to;
}

inline static std::string MOVE_DESCRIPTION(Move move) {
    auto fromSquare = SquareNames[MOVE_FROM(move)];
    auto toSquare = SquareNames[MOVE_TO(move)];
    return fromSquare+toSquare;
}
