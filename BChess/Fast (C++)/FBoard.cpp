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
#include "magicmoves.h"

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

inline static int file_index(int square) {
    return square >> 3;
}

inline static int rank_index(int square) {
    return square & 7;
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

static Bitboard IWhiteKnights = BB(0b\
00000000\
00000000\
00000000\
00000000\
00000000\
00000000\
00000000\
01000010\
);

static Bitboard IBlackKnights = BB(0b\
01000010\
00000000\
00000000\
00000000\
00000000\
00000000\
00000000\
00000000\
);

static Bitboard IWhiteRooks = BB(0b\
00000000\
00000000\
00000000\
00000000\
00000000\
00000000\
00000000\
10000001\
);

static Bitboard IBlackRooks = BB(0b\
10000001\
00000000\
00000000\
00000000\
00000000\
00000000\
00000000\
00000000\
);

static Bitboard IWhiteKing = BB(0b\
00000000\
00000000\
00000000\
00000000\
00000000\
00000000\
00000000\
00001000\
);

static Bitboard IBlackKing = BB(0b\
00001000\
00000000\
00000000\
00000000\
00000000\
00000000\
00000000\
00000000\
);

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

inline static int lsb(Bitboard bb) {
    assert(bb > 0);
    return __builtin_ctzll(bb);
}

#pragma mark -

void MoveList::addMoves(int from, Bitboard moves) {
    while (moves > 0) {
        int to = lsb(moves);
        bb_clear(moves, to);
        
        addMove(from, to);
    }
}

#pragma mark -

FastMoveGenerator::FastMoveGenerator() {
    initPawnMoves();
    initKingMoves();
    initKnightMoves();
}

void FastMoveGenerator::initPawnMoves() {
    for (int square = 8; square < 64-8; square++) {
        int fileIndex = file_index(square);
        int rankIndex = rank_index(square);

        // White pawn attacks
        bb_set(WhitePawnAttacks[square], fileIndex+1, rankIndex-1);
        bb_set(WhitePawnAttacks[square], fileIndex+1, rankIndex+1);
        
        // White pawn moves
        bb_set(WhitePawnMoves[square], fileIndex+1, rankIndex);
        bb_set(WhitePawnMoves[square], fileIndex+2, rankIndex);
        
        // Black pawn attacks
        bb_set(BlackPawnAttacks[square], fileIndex-1, rankIndex-1);
        bb_set(BlackPawnAttacks[square], fileIndex-1, rankIndex+1);
        
        // Black pawn moves
        bb_set(BlackPawnMoves[square], fileIndex-1, rankIndex);
        bb_set(BlackPawnMoves[square], fileIndex-2, rankIndex);
    }
}

void FastMoveGenerator::initKingMoves() {
    for (int square = 0; square < 64; square++) {
        int fileIndex = file_index(square);
        int rankIndex = rank_index(square);
        
        bb_set(KingMoves[square], fileIndex, rankIndex+1);
        bb_set(KingMoves[square], fileIndex+1, rankIndex+1);
        bb_set(KingMoves[square], fileIndex+1, rankIndex);
        bb_set(KingMoves[square], fileIndex+1, rankIndex-1);
        bb_set(KingMoves[square], fileIndex, rankIndex-1);
        bb_set(KingMoves[square], fileIndex-1, rankIndex-1);
        bb_set(KingMoves[square], fileIndex-1, rankIndex);
        bb_set(KingMoves[square], fileIndex-1, rankIndex+1);
    }
}

void FastMoveGenerator::initKnightMoves() {
    for (int square = 0; square < 64; square++) {
        int fileIndex = file_index(square);
        int rankIndex = rank_index(square);
        
        // Top
        bb_set(KnightMoves[square], fileIndex-1, rankIndex+2);
        bb_set(KnightMoves[square], fileIndex+1, rankIndex+2);

        // Bottom
        bb_set(KnightMoves[square], fileIndex-1, rankIndex-2);
        bb_set(KnightMoves[square], fileIndex+1, rankIndex-2);
        
        // Left
        bb_set(KnightMoves[square], fileIndex-2, rankIndex+1);
        bb_set(KnightMoves[square], fileIndex-2, rankIndex-1);

        // Right
        bb_set(KnightMoves[square], fileIndex+2, rankIndex+1);
        bb_set(KnightMoves[square], fileIndex+2, rankIndex-1);
    }
}

void FastMoveGenerator::generateMoves() {
    MoveList moveList;
    Board board;
    
    initmagicmoves();
    
    board.pieces[Color::WHITE][Piece::PAWN] = IWhitePawns;
    board.pieces[Color::WHITE][Piece::KING] = IWhiteKing;
    board.pieces[Color::WHITE][Piece::ROOK] = IWhiteRooks;
    board.pieces[Color::WHITE][Piece::KNIGHT] = IWhiteKnights;

    board.whitePieces = IWhitePawns | IWhiteKnights | IWhiteKing | IWhiteRooks;
    board.blackPieces = IBlackPawns | IBlackKnights | IBlackKing | IBlackRooks;

    generatePawnsMoves(board, moveList);
    generateKingsMoves(board, moveList);
    generateKnightsMoves(board, moveList);
    generateRooksMoves(board, moveList);

    for (int i=0; i<moveList.moveCount; i++) {
        auto move = moveList.moves[i];
        std::cout << SquareNames[move.from] << SquareNames[move.to] << std::endl;
    }
}

void FastMoveGenerator::generatePawnsMoves(Board &board, MoveList &moveList) {
    auto whitePawns = board.pieces[Color::WHITE][Piece::PAWN];
    auto emptySquares = ~(board.whitePieces|board.blackPieces);
    
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
        auto attacks = WhitePawnAttacks[square] & board.blackPieces;
        moveList.addMoves(square, attacks);
        
        // Generate a bitboard for all the moves that this white pawn can do.
        // The move bitboard is masked with the empty bitboard which
        // in other words ensures that the pawn can only move to unoccupied square.
        auto moves = WhitePawnMoves[square] & emptySquares;
        moveList.addMoves(square, moves);
    }
}

void FastMoveGenerator::generateKingsMoves(Board &board, MoveList &moveList) {
    auto kings = board.pieces[Color::WHITE][Piece::KING];
    auto emptyOrBlackSquares = ~(board.whitePieces|board.blackPieces) | board.blackPieces;
    
    // Generate moves for each white knight
    while (kings > 0) {
        // Find the first white knight starting from the least significant bit (that is, square a1)
        int square = lsb(kings);
        
        // Clear that bit so next time we can find the next white knight
        bb_clear(kings, square);
        
        // Generate a bitboard for all the moves that this white knight
        // can do. The attacks bitboard is masked to ensure it can only
        // happy on an empty square or a square with a piece of the opposite color.
        auto moves = KingMoves[square] & emptyOrBlackSquares;
        moveList.addMoves(square, moves);
    }
}

void FastMoveGenerator::generateKnightsMoves(Board &board, MoveList &moveList) {
    auto whiteKnights = board.pieces[Color::WHITE][Piece::KNIGHT];
    auto emptyOrBlackSquares = ~board.whitePieces;
    
    // Generate moves for each white knight
    while (whiteKnights > 0) {
        // Find the first white knight starting from the least significant bit (that is, square a1)
        int square = lsb(whiteKnights);
        
        // Clear that bit so next time we can find the next white knight
        bb_clear(whiteKnights, square);
        
        // Generate a bitboard for all the moves that this white knight
        // can do. The attacks bitboard is masked to ensure it can only
        // happy on an empty square or a square with a piece of the opposite color.
        auto moves = KnightMoves[square] & emptyOrBlackSquares;
        moveList.addMoves(square, moves);
    }
}

void FastMoveGenerator::generateRooksMoves(Board &board, MoveList &moveList) {
    auto rooks = board.pieces[Color::WHITE][Piece::ROOK];
    auto occupancy = board.whitePieces|board.blackPieces;
    auto emptyOrBlackSquares = ~board.whitePieces;
    
    // Generate moves for each white knight
    while (rooks > 0) {
        // Find the first white knight starting from the least significant bit (that is, square a1)
        int square = lsb(rooks);
        
        // Clear that bit so next time we can find the next white knight
        bb_clear(rooks, square);
        
        // Generate a bitboard for all the moves that this rook can do.
        auto potentialMoves = Rmagic(square, occupancy);
        
        // Note: the occupancy bitboard has all the white and black pieces,
        // we need to filter out the moves that land into a piece of the same
        // color because Rmagic will move to these squares anyway.
        auto moves = potentialMoves & emptyOrBlackSquares;
        
        moveList.addMoves(square, moves);
    }
}

