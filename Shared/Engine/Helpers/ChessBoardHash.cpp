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

// Index: white king side, white queen side, black king side, black queen side
static uint64_t castling[4];

static uint64_t enPassantFile[8];

void ChessBoardHash::initialize() {
    PRNG rng(1070372);
    for (Square square=0; square<64; square++) {
        for (int piece=0; piece<12; piece++) {
            zobrist[square][piece] = rng.rand<BoardHash>();
        }
    }
    side = rng.rand<BoardHash>();
    for (auto &key : castling) {
        key = rng.rand<BoardHash>();
    }
    for (auto &key : enPassantFile) {
        key = rng.rand<BoardHash>();
    }
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
    
    h ^= stateKey(board);
    
    return h;
}

uint64_t ChessBoardHash::getPseudoNumber(Square square, Color color, Piece piece) {
    int offsetPiece = color == WHITE ? 0 : PCOUNT;
    return zobrist[square][piece+offsetPiece];
}

uint64_t ChessBoardHash::getWhiteTurn() {
    return side;
}


// True when a pawn of the side to move can capture en passant without leaving its king in check.
// Done with direct bitboard edits on a copy, never with move() or the generator, because move()
// calls stateKey().
static bool canCaptureEnPassant(const ChessBoard &board) {
    auto color = board.color;
    if (!board.isEnPassantTargetValid(color)) {
        return false;
    }
    Square target = lsb(board.enPassant);
    
    // Same trick as isAttacked(): a pawn of the other color placed on the target square sees the
    // squares our pawns capture from
    Bitboard candidates = PawnAttacks[INVERSE(color)][target] & board.pieces[color][PAWN];
    while (candidates) {
        Square from = lsb(candidates);
        bb_clear(candidates, from);
        
        ChessBoard copy = board;
        bb_clear(copy.pieces[color][PAWN], from);
        bb_set(copy.pieces[color][PAWN], target);
        bb_clear(copy.pieces[INVERSE(color)][PAWN], color == WHITE ? target - 8 : target + 8);
        copy.occupancyDirty = true;
        if (!copy.isCheck(color)) {
            return true;
        }
    }
    return false;
}

uint64_t ChessBoardHash::castlingKey(int right) {
    return castling[right];
}

uint64_t ChessBoardHash::enPassantKey(const ChessBoard &board) {
    return canCaptureEnPassant(board) ? enPassantFile[FileFrom(lsb(board.enPassant))] : 0;
}

uint64_t ChessBoardHash::stateKey(const ChessBoard &board) {
    uint64_t key = 0;
    if (board.whiteCanCastleKingSide) key ^= castling[0];
    if (board.whiteCanCastleQueenSide) key ^= castling[1];
    if (board.blackCanCastleKingSide) key ^= castling[2];
    if (board.blackCanCastleQueenSide) key ^= castling[3];
    return key ^ enPassantKey(board);
}
