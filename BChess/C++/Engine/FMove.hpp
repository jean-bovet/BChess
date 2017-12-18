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
// bit 18-20: 3 bits for promotion PIECE (from 0 to 6). 0 means no promotion.
// bit 21-23: 3 bits for captured PIECE (from 0 to 6).
typedef uint32_t Move;

inline static Move createMove(Square from, Square to, Color color, Piece piece) {
    Move m = (Move)(from | (Move)to << 6 | color << 12 | piece << 13);
    return m;
}

inline static Move createPromotion(Square from, Square to, Color color, Piece piece, Piece promotionPiece) {
    Move m = createMove(from, to, color, piece);
    m |= promotionPiece << 18;
    return m;
}

inline static Move createCapture(Square from, Square to, Color color, Piece attackingPiece, Piece capturedPiece) {
    Move m = createMove(from, to, color, attackingPiece);
    m |= 1UL << 16;
    m |= capturedPiece << 21;
    return m;
}

inline static Move createEnPassant(Square from, Square to, Color color, Piece piece) {
    Move m = createCapture(from, to, color, piece, PAWN);
    m |= 1UL << 17;
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

inline static Piece MOVE_PROMOTION_PIECE(Move move) {
    uint8_t test = (move >> 18) & 7;
    return Piece(test);
}

inline static Piece MOVE_CAPTURED_PIECE(Move move) {
    uint8_t test = (move >> 21) & 7;
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

