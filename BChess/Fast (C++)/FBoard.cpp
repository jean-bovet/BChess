//
//  FBoard.cpp
//  BChess
//
//  Created by Jean Bovet on 11/26/17.
//  Copyright © 2017 Jean Bovet. All rights reserved.
//

#include "FBoard.hpp"
#include <bitstring.h>
#include <iostream>
#include <cassert>

/**
file
    8
    7
    6
    5
    4
    3
    2
    1 a1 b1 c1 d1 e1 f1 g1 h1
      a  b  c  d  e  f  g  h  <- rank
    a1 = 0
    h1 = 2^7 = 128
    h8 = 2^63
 */

inline static int square_index(int file, int rank) {
    return 8 * file + rank;
}

inline static bool bb_test(Bitboard bitboard, int file, int rank) {
    uint64_t square = (uint64_t)1 << square_index(file, rank);
    uint64_t test = bitboard & square;
    return test > 0;
}

inline static void bb_clear(Bitboard &bitboard, uint64_t square) {
    bitboard &= ~(1UL << square);
}

inline static void bb_set(Bitboard &bitboard, uint64_t square) {
    bitboard |= square;
}

inline static void bb_set(Bitboard &bitboard, int file, int rank) {
    if (file >= 0 && file <= 7 && rank >= 0 && rank <= 7) {
        uint64_t square = (uint64_t)1 << square_index(file, rank);
        bb_set(bitboard, square);
    }
}

inline static void bb_print(Bitboard bitboard) {
    for (int file = 7; file >= 0; file--) {
        for (int rank = 0; rank < 8; rank++) {
            std::cout << (bb_test(bitboard, file, rank) > 0  ? "X" : ".");
        }
        std::cout << std::endl;
    }
    std::cout << std::endl;
}

inline static Bitboard BB(Bitboard userDefined) {
    Bitboard reversed = 0;
    for (int file = 0; file < 8; file++) {
        for (int rank = 0; rank < 8; rank++) {
            if (bb_test(userDefined, file, 7 - rank)) {
                bb_set(reversed, file, rank);
            }
        }
    }
    return reversed;
}

// popcount
// ffs

static Bitboard IWhitePawns = BB(0b\
00000000\
00000000\
00000000\
00000000\
00000000\
00000000\
11111111\
00000000\
);

static Bitboard IBlackPawns = BB(0b\
00000000\
11111111\
00000000\
00000000\
00000000\
00000000\
00000000\
00000000\
);

/**
 .XXXXXXX
 .XXXXXXX
 .XXXXXXX
 .XXXXXXX
 .XXXXXXX
 .XXXXXXX
 .XXXXXXX
 .XXXXXXX
 */
//static Bitboard leftPawnAttackMask = 0x7f7f7f7f7f7f7f7f;

/**
 XXXXXXX.
 XXXXXXX.
 XXXXXXX.
 XXXXXXX.
 XXXXXXX.
 XXXXXXX.
 XXXXXXX.
 XXXXXXX.
 */
//static Bitboard rightPawnAttackMask = 0xfefefefefefefefe;

//inline static Bitboard whitePawnsAttacks(Bitboard board) {
//    Bitboard attacks = 0;
//
//    attacks |= (board & leftPawnAttackMask) << 9; // shit all the pawn by one square to the left on the row above it
//    attacks |= (board & rightPawnAttackMask) << 7; // shit all the pawn by one square to the right on the row above it
//
//    return attacks;
//}

inline static int lsb(Bitboard bb) {
    assert(bb > 0);
    return __builtin_ctzll(bb);
}

#pragma mark -

void MoveList::addMoves(int from, Bitboard moves) {
    if (moves > 0) {
        //            bb_print(moves);
        while (moves > 0) {
            int to = lsb(moves);
            bb_clear(moves, to);
            
            addMove(from, to);
        }
    }
}

#pragma mark -

FastMoveGenerator::FastMoveGenerator() {
    initPawnAttacks();
}

void FastMoveGenerator::initPawnAttacks() {
//    bb_print(InitialWhitePawns);
    
    for (int square = 8; square < 64-8; square++) {
        int fileIndex = square >> 3;
        int rankIndex = square & 7;

        // White pawn attacks
        bb_set(WhitePawnAttacks[square], fileIndex+1, rankIndex-1);
        bb_set(WhitePawnAttacks[square], fileIndex+1, rankIndex+1);
        
        bb_set(WhitePawnMoves[square], fileIndex+1, rankIndex);
        bb_set(WhitePawnMoves[square], fileIndex+2, rankIndex);
    }
    
    for (int square = 8; square < 64-8; square++) {
        int fileIndex = square >> 3;
        int rankIndex = square & 7;
        
        // Black pawn attacks
        bb_set(BlackPawnAttacks[square], fileIndex-1, rankIndex-1);
        bb_set(BlackPawnAttacks[square], fileIndex-1, rankIndex+1);
        
        bb_set(BlackPawnMoves[square], fileIndex-1, rankIndex);
        bb_set(BlackPawnMoves[square], fileIndex-2, rankIndex);
    }

//    bb_print(IWhitePawns);
//    bb_print(IBlackPawns);
    
}

void FastMoveGenerator::generateMoves() {
    MoveList moveList;
    generatePawnsMoves(moveList);
    
    for (int i=0; i<moveList.moveCount; i++) {
        auto move = moveList.moves[i];
        std::cout << SquareNames[move.from] << SquareNames[move.to] << std::endl;
    }
}

void FastMoveGenerator::generatePawnsMoves(MoveList &moveList) {
    Bitboard occupancy = IWhitePawns | IBlackPawns;
    bb_print(occupancy);
    
    Bitboard whitePawns = IWhitePawns;
    Bitboard emptySquares = ~occupancy;
    
    // Generate moves for each white pawn
    while (whitePawns > 0) {
        // Find the first white pawn starting from the least significant bit (that is, square a1)
        int square = lsb(whitePawns);
        
        // Clear that bit so next time we can find the next white pawn
        bb_clear(whitePawns, square);
        
        // Generate a bitboard for all the attacks that this white pawn
        // can do. The attacks bitboard is masked with the occupancy bitboard
        // because a pawn attack can only happen when there is a black piece
        // in the target square.
        // TODO: occupancy should actually be black occupancy
        // Using white occupancy, we can detect which piece is protected!
        Bitboard attacks = WhitePawnAttacks[square] & occupancy;
        moveList.addMoves(square, attacks);
        
        // Generate a bitboard for all the moves that this white pawn can do.
        // The move bitboard is masked with the empty bitboard which
        // in other words ensures that the pawn can only move to unoccupied square.
        Bitboard moves = WhitePawnMoves[square] & emptySquares;
        moveList.addMoves(square, moves);
    }
}

