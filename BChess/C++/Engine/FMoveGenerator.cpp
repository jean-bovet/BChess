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

bool FastMoveGenerator::magicInitialized = false;

FastMoveGenerator::FastMoveGenerator() {
    if (!magicInitialized) {
        initmagicmoves();
        magicInitialized = true;
    }
    initPawnMoves();
    initKingMoves();
    initKnightMoves();
}

void FastMoveGenerator::initPawnMoves() {
    for (int square = 8; square < 64-8; square++) {
        int fileIndex = file_index(square);
        int rankIndex = rank_index(square);
        
        assert(square_index(fileIndex, rankIndex) == square);
        
        // White pawn attacks
        bb_set(PawnAttacks[Color::WHITE][square], fileIndex-1, rankIndex+1);
        bb_set(PawnAttacks[Color::WHITE][square], fileIndex+1, rankIndex+1);
        
        // White pawn moves
        bb_set(PawnMoves[Color::WHITE][square], fileIndex, rankIndex+1);
        if (rankIndex == 1) {
            bb_set(PawnMoves[Color::WHITE][square], fileIndex, rankIndex+2);
        }
        
        // Black pawn attacks
        bb_set(PawnAttacks[Color::BLACK][square], fileIndex-1, rankIndex-1);
        bb_set(PawnAttacks[Color::BLACK][square], fileIndex+1, rankIndex-1);
        
        // Black pawn moves
        bb_set(PawnMoves[Color::BLACK][square], fileIndex, rankIndex-1);
        if (rankIndex == 6) {
            bb_set(PawnMoves[Color::BLACK][square], fileIndex, rankIndex-2);
        }
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

MoveList FastMoveGenerator::generateMoves(Board board, Color color, int squareIndex) {
    MoveList moveList;
    
    generatePawnsMoves(board, color, moveList, squareIndex);
    generateKingsMoves(board, color, moveList, squareIndex);
    generateKnightsMoves(board, color, moveList, squareIndex);
    generateSlidingMoves(board, color, Piece::ROOK, moveList, squareIndex);
    generateSlidingMoves(board, color, Piece::BISHOP, moveList, squareIndex);
    generateSlidingMoves(board, color, Piece::QUEEN, moveList, squareIndex);
    
    //    for (int i=0; i<moveList.moveCount; i++) {
    //        auto move = moveList.moves[i];
    ////        std::cout << SquareNames[move.from] << SquareNames[move.to] << std::endl;
    //        auto newBoard = board;
    //        newBoard.move(move);
    //        bb_print(newBoard.occupancy());
    //    }
    
    return moveList;
}

void FastMoveGenerator::generatePawnsMoves(Board &board, Color color, MoveList &moveList, int squareIndex) {
    auto pawns = board.pieces[color][Piece::PAWN];
    auto emptySquares = board.emptySquares();
    auto blackPieces = board.allPieces(INVERSE(color));
    
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
        // TODO: occupancy should actually be black occupancy
        // Using white occupancy, we can detect which piece is protected!
        auto attacks = PawnAttacks[color][square] & blackPieces;
        moveList.addMoves(board, square, attacks, color, Piece::PAWN);
        
        // Generate a bitboard for all the moves that this white pawn can do.
        // The move bitboard is masked with the empty bitboard which
        // in other words ensures that the pawn can only move to unoccupied square.
        auto moves = PawnMoves[color][square] & emptySquares;
        moveList.addMoves(board, square, moves, color, Piece::PAWN);
    }
}

void FastMoveGenerator::generateKingsMoves(Board &board, Color color, MoveList &moveList, int squareIndex) {
    auto kings = board.pieces[color][Piece::KING];
    auto emptyOrBlackSquares = ~board.allPieces(color);
    
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
        moveList.addMoves(board, square, moves, color, Piece::KING);
    }
}

void FastMoveGenerator::generateKnightsMoves(Board &board, Color color, MoveList &moveList, int squareIndex) {
    auto whiteKnights = board.pieces[color][Piece::KNIGHT];
    auto emptyOrBlackSquares = ~board.allPieces(color);
    
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
        moveList.addMoves(board, square, moves, color, Piece::KNIGHT);
    }
}

void FastMoveGenerator::generateSlidingMoves(Board &board, Color color, Piece piece, MoveList &moveList, int squareIndex) {
    auto slidingPieces = board.pieces[color][piece];
    auto occupancy = board.occupancy();
    auto emptyOrBlackSquares = ~board.allPieces(color);
    
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
            case Piece::ROOK:
                potentialMoves = Rmagic(square, occupancy);
                break;
                
            case Piece::BISHOP:
                potentialMoves = Bmagic(square, occupancy);
                break;
                
            case Piece::QUEEN:
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
        moveList.addMoves(board, square, moves, color, piece);
    }
}
