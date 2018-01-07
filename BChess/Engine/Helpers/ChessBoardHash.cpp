//
//  ChessBoardHash.cpp
//  BChess
//
//  Created by Jean Bovet on 1/6/18.
//  Copyright © 2018 Jean Bovet. All rights reserved.
//

#include "ChessBoardHash.hpp"

#include <random>

static uint64_t zobristTable[64][12];

// See https://en.wikipedia.org/wiki/Zobrist_hashing
// See https://chessprogramming.wikispaces.com/Zobrist+Hashing
void ChessBoardHash::initialize() {
    std::random_device rd;
    std::mt19937_64 e2(rd());
    std::uniform_int_distribution<long long int> dist(std::llround(std::pow(2,61)), std::llround(std::pow(2,62)));
    
    for (Square square=0; square<64; square++) {
        for (int piece=0; piece<12; piece++) {
            zobristTable[square][piece] = dist(e2);
        }
    }
}

BoardHash ChessBoardHash::hash(ChessBoard board) {
    uint64_t h = 0;
    for (Square square=0; square<64; square++) {
        auto file = FileFrom(square);
        auto rank = RankFrom(square);
        auto boardSquare = board.get(file, rank);
        if (boardSquare.empty) continue;
        
        int offset = boardSquare.color == WHITE ? 0 : PCOUNT;
        int pieceIndex = boardSquare.piece + offset;
        h = h xor zobristTable[square][pieceIndex];
    }
    return h;
}
