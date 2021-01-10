//
//  ChessBoardHash.cpp
//  BChess
//
//  Created by Jean Bovet on 1/6/18.
//  Copyright © 2018 Jean Bovet. All rights reserved.
//

#include "ChessBoardHash.hpp"

/// xorshift64star Pseudo-Random Number Generator
/// This class is based on original code written and dedicated
/// to the public domain by Sebastiano Vigna (2014).
/// It has the following characteristics:
///
///  -  Outputs 64-bit numbers
///  -  Passes Dieharder and SmallCrush test batteries
///  -  Does not require warm-up, no zeroland to escape
///  -  Internal state is a single 64-bit integer
///  -  Period is 2^64 - 1
///  -  Speed: 1.60 ns/call (Core i7 @3.40GHz)
///
/// For further analysis see
///   <http://vigna.di.unimi.it/ftp/papers/xorshift.pdf>
/// Taken from the stockfish source code
class PRNG {
    
    uint64_t s;
    
    uint64_t rand64() {
        s ^= s >> 12;
        s ^= s << 25;
        s ^= s >> 27;
        return s * 2685821657736338717LL;
    }
    
public:
    PRNG(uint64_t seed) : s(seed) { assert(seed); }
    
    template<typename T> T rand() { return T(rand64()); }
    
    /// Special generator used to fast init magic numbers.
    /// Output values only have 1/8th of their bits set on average.
    template<typename T> T sparse_rand()
    { return T(rand64() & rand64() & rand64()); }
};

// See https://en.wikipedia.org/wiki/Zobrist_hashing
// See https://chessprogramming.wikispaces.com/Zobrist+Hashing

static uint64_t zobrist[64][12];

static uint64_t side;

void ChessBoardHash::initialize() {
    PRNG rng(1070372);
    for (Square square=0; square<64; square++) {
        for (int piece=0; piece<12; piece++) {
            zobrist[square][piece] = rng.rand<BoardHash>();
        }
    }
    side = rng.rand<BoardHash>();
}

BoardHash ChessBoardHash::hash(ChessBoard board) {
    uint64_t h = 0;
    for (Square square=0; square<64; square++) {
        auto file = FileFrom(square);
        auto rank = RankFrom(square);
        auto boardSquare = board.get(file, rank);
        if (boardSquare.empty) continue;
        
        h ^= getPseudoNumber(square, boardSquare.color, boardSquare.piece);
    }
    
    if (board.color == WHITE) {
        h ^= side;
    }
    
    return h;
}

uint64_t ChessBoardHash::getPseudoNumber(Square square, Color color, Piece piece) {
    int offsetPiece = color == WHITE ? 0 : PCOUNT;
    return zobrist[square][piece+offsetPiece];
}

uint64_t ChessBoardHash::getWhiteTurn() {
    return side;
}

