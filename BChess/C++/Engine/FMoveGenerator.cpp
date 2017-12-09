//
//  FMoveGenerator.cpp
//  BChess
//
//  Created by Jean Bovet on 12/3/17.
//  Copyright © 2017 Jean Bovet. All rights reserved.
//

#include "FMoveGenerator.hpp"
#include "magicmoves.h"

#include <cassert>

void MoveGenerator::initialize() {
    initmagicmoves();
    initPawnMoves();
    initKingMoves();
    initKnightMoves();
}

void MoveGenerator::initPawnMoves() {
    // Note: generate moves even for the first and last rank, because it
    // is used by the some functions to determine if a piece is attacked
    // by a pawn which might need white pawn in the first rank or a black
    // pawn in the last rank to determine proper attack.
    for (int square = 0; square < 64; square++) {
        int fileIndex = file_index(square);
        int rankIndex = rank_index(square);
        
        assert(square_index(fileIndex, rankIndex) == square);
        
        // White pawn attacks
        bb_set(PawnAttacks[WHITE][square], fileIndex-1, rankIndex+1);
        bb_set(PawnAttacks[WHITE][square], fileIndex+1, rankIndex+1);
        
        // White pawn moves
        bb_set(PawnMoves[WHITE][square], fileIndex, rankIndex+1);
        if (rankIndex == 1) {
            bb_set(PawnMoves[WHITE][square], fileIndex, rankIndex+2);
        }
        
        // Black pawn attacks
        bb_set(PawnAttacks[BLACK][square], fileIndex-1, rankIndex-1);
        bb_set(PawnAttacks[BLACK][square], fileIndex+1, rankIndex-1);
        
        // Black pawn moves
        bb_set(PawnMoves[BLACK][square], fileIndex, rankIndex-1);
        if (rankIndex == 6) {
            bb_set(PawnMoves[BLACK][square], fileIndex, rankIndex-2);
        }
    }
}

void MoveGenerator::initKingMoves() {
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

void MoveGenerator::initKnightMoves() {
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

MoveList MoveGenerator::generateMoves(Board board, int squareIndex) {
    MoveList moveList;
    
    generatePawnsMoves(board, moveList, squareIndex);
    generateKingsMoves(board, moveList, squareIndex);
    generateKnightsMoves(board, moveList, squareIndex);
    generateSlidingMoves(board, ROOK, moveList, squareIndex);
    generateSlidingMoves(board, BISHOP, moveList, squareIndex);
    generateSlidingMoves(board, QUEEN, moveList, squareIndex);
    
    return moveList;
}

void MoveGenerator::generatePawnsMoves(Board &board, MoveList &moveList, int squareIndex) {
    auto pawns = board.pieces[board.color][PAWN];
    auto emptySquares = board.emptySquares();
    auto blackPieces = board.allPieces(INVERSE(board.color));
    
    // Generate moves for each white pawn
    while (pawns > 0) {
        // Find the first white pawn starting from the least significant bit (that is, square a1)
        int square = lsb(pawns);
        
        // If the square index is specified, only generate move for that square
        if (squareIndex > -1 && square != squareIndex) {
            break;
        }
        
        // Clear that bit so next time we can find the next white pawn
        bb_clear(pawns, square);
        
        // Generate a bitboard for all the attacks that this white pawn
        // can do. The attacks bitboard is masked with the occupancy bitboard
        // because a pawn attack can only happen when there is a black piece
        // in the target square.
        auto attacks = PawnAttacks[board.color][square] & blackPieces;
        moveList.addMoves(board, square, attacks, PAWN);
        
        // Generate a bitboard for all the moves that this white pawn can do.
        // The move bitboard is masked with the empty bitboard which
        // in other words ensures that the pawn can only move to unoccupied square.
        auto moves = PawnMoves[board.color][square] & emptySquares;
        if (moves > 0) {
            // Note: mask with Rook Moves to ensure the pawn doesn't "step" over
            // a piece when moving 2 ranks at starting position.
            auto rookMoves = Rmagic(square, board.getOccupancy());
            moves &= rookMoves;
        }
        moveList.addMoves(board, square, moves, PAWN);
    }
}

void MoveGenerator::generateKingsMoves(Board &board, MoveList &moveList, int squareIndex) {
    auto kings = board.pieces[board.color][KING];
    auto emptyOrBlackSquares = ~board.allPieces(board.color);
    
    // Generate moves for each white knight
    while (kings > 0) {
        // Find the first white knight starting from the least significant bit (that is, square a1)
        int square = lsb(kings);
        
        // If the square index is specified, only generate move for that square
        if (squareIndex > -1 && square != squareIndex) {
            break;
        }
        
        // Clear that bit so next time we can find the next white knight
        bb_clear(kings, square);
        
        // Generate a bitboard for all the moves that this white knight
        // can do. The attacks bitboard is masked to ensure it can only
        // happy on an empty square or a square with a piece of the opposite color.
        auto moves = KingMoves[square] & emptyOrBlackSquares;
        moveList.addMoves(board, square, moves, KING);
    }
}

void MoveGenerator::generateKnightsMoves(Board &board, MoveList &moveList, int squareIndex) {
    auto whiteKnights = board.pieces[board.color][KNIGHT];
    auto emptyOrBlackSquares = ~board.allPieces(board.color);
    
    // Generate moves for each white knight
    while (whiteKnights > 0) {
        // Find the first white knight starting from the least significant bit (that is, square a1)
        int square = lsb(whiteKnights);
        
        // If the square index is specified, only generate move for that square
        if (squareIndex > -1 && square != squareIndex) {
            break;
        }
        
        // Clear that bit so next time we can find the next white knight
        bb_clear(whiteKnights, square);
        
        // Generate a bitboard for all the moves that this white knight
        // can do. The attacks bitboard is masked to ensure it can only
        // happy on an empty square or a square with a piece of the opposite color.
        auto moves = KnightMoves[square] & emptyOrBlackSquares;
        moveList.addMoves(board, square, moves, KNIGHT);
    }
}

void MoveGenerator::generateSlidingMoves(Board &board, Piece piece, MoveList &moveList, int squareIndex) {
    auto slidingPieces = board.pieces[board.color][piece];
    auto occupancy = board.getOccupancy();
    auto emptyOrBlackSquares = ~board.allPieces(board.color);
    
    // Generate moves for each sliding piece
    while (slidingPieces > 0) {
        // Find the first sliding piece starting from the least significant bit (that is, square a1)
        int square = lsb(slidingPieces);
        
        // If the square index is specified, only generate move for that square
        if (squareIndex > -1 && square != squareIndex) {
            break;
        }
        
        // Clear that bit so next time we can find the next sliding piece
        bb_clear(slidingPieces, square);
        
        // Generate a bitboard for all the moves that this sliding piece can do.
        Bitboard potentialMoves;
        switch (piece) {
            case ROOK:
                potentialMoves = Rmagic(square, occupancy);
                break;
                
            case BISHOP:
                potentialMoves = Bmagic(square, occupancy);
                break;
                
            case QUEEN:
                potentialMoves = Rmagic(square, occupancy) | Bmagic(square, occupancy);
                break;
                
            default:
                assert(false); // not a sliding piece
                break;
        }
        
        // Note: the occupancy bitboard has all the white and black pieces,
        // we need to filter out the moves that land into a piece of the same
        // color because Rmagic will move to these squares anyway.
        auto moves = potentialMoves & emptyOrBlackSquares;
        moveList.addMoves(board, square, moves, piece);
    }
}
