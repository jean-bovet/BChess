//
//  FMove.hpp
//  BChess
//
//  Created by Jean Bovet on 12/3/17.
//  Copyright © 2017 Jean Bovet. All rights reserved.
//

#pragma once

#include "Color.hpp"
#include "Piece.hpp"
#include "Coordinate.hpp"

#include <string>

// A move needs 32 bits to be stored
// bit 0-5: destination square (from 0 to 63)
// bit 6-11: origin square (from 0 to 63)
// bit 12: 1=BLACK, 0=WHITE (color of piece being moved)
// bit 13-15: 3 bits for PIECE (from 0 to 6)
// bit 16: 0=move, 1=capture
// bit 17: 1=en passant, 0 otherwise
// bit 18-20: 3 bits for promotion PIECE (from 0 to 6). 0 means no promotion.
// bit 21-23: 3 bits for captured PIECE (from 0 to 6).
// bit 24: 0=nothing, 1=check move
// bit 25: 1=BLACK, 0=WHITE (color of piece being attacked)
// bit 26: 0=nothing, 1=castling
typedef uint32_t Move;

static const Move INVALID_MOVE = 0;

inline static bool MOVE_ISVALID(Move move) {
    return move != INVALID_MOVE;
}

inline static void SET_MOVE_IS_CHECK(Move & move) {
    move &= ~(1UL << 24);
    move |= 1UL << 24;
}

inline static bool MOVE_IS_CHECK(Move move) {
    uint32_t test = move & (1UL << 24);
    return test > 0;
}

inline static bool MOVE_IS_CAPTURE(Move move) {
    uint32_t test = move & (1UL << 16);
    return test > 0;
}

inline static bool MOVE_IS_ENPASSANT(Move move) {
    uint32_t test = move & (1UL << 17);
    return test > 0;
}

inline static bool MOVE_IS_CASTLING(Move move) {
    uint32_t test = move & (1UL << 26);
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

inline static void SET_MOVE_PROMOTION_PIECE(Move & move, Piece promotionPiece) {
    move &= ~(7UL << 18);
    move |= promotionPiece << 18;
}

inline static Piece MOVE_PROMOTION_PIECE(Move move) {
    uint8_t test = (move >> 18) & 7;
    return Piece(test);
}

inline static Piece MOVE_CAPTURED_PIECE(Move move) {
    uint8_t test = (move >> 21) & 7;
    return Piece(test);
}

inline static Color MOVE_CAPTURED_PIECE_COLOR(Move move) {
    uint32_t test = move & (1UL << 25);
    return test > 0 ? BLACK : WHITE;
}

inline static Square MOVE_FROM(Move move) {
    Square from = move & 63;
    return from;
}

inline static Square MOVE_TO(Move move) {
    Square to = (move >> 6) & 63;
    return to;
}

inline static Move createMove(Square from, Square to, Color color, Piece piece) {
    Move m = (Move)(from | (Move)to << 6 | color << 12 | piece << 13);
    return m;
}

inline static Move createCastling(Square from, Square to, Color color, Piece piece) {
    Move m = createMove(from, to, color, piece);
    m |= 1UL << 26;
    return m;
}

inline static Move createPromotion(Square from, Square to, Color color, Piece piece, Piece promotionPiece) {
    Move m = createMove(from, to, color, piece);
    SET_MOVE_PROMOTION_PIECE(m, promotionPiece);
    return m;
}

inline static Move createCapture(Square from, Square to, Color color, Piece attackingPiece, Color capturedPieceColor, Piece capturedPiece) {
    Move m = createMove(from, to, color, attackingPiece);
    m |= 1UL << 16;
    m |= capturedPiece << 21;
    m |= capturedPieceColor << 25;
    return m;
}

inline static Move createEnPassant(Square from, Square to, Color color, Piece piece) {
    Move m = createCapture(from, to, color, piece, INVERSE(color), PAWN);
    m |= 1UL << 17;
    return m;
}

