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
    for (Square square = 0; square < 64; square++) {
        auto fileIndex = FileFrom(square);
        auto rankIndex = RankFrom(square);
        
        assert(SquareFrom(fileIndex, rankIndex) == square);
        
        // White pawn attacks
        bb_set(PawnAttacks[WHITE][square], fileIndex-1, rankIndex+1);
        bb_set(PawnAttacks[WHITE][square], fileIndex+1, rankIndex+1);
        
        // Black pawn attacks
        bb_set(PawnAttacks[BLACK][square], fileIndex-1, rankIndex-1);
        bb_set(PawnAttacks[BLACK][square], fileIndex+1, rankIndex-1);
    }
}

void MoveGenerator::initKingMoves() {
    for (Square square = 0; square < 64; square++) {
        auto fileIndex = FileFrom(square);
        auto rankIndex = RankFrom(square);
        
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
    for (Square square = 0; square < 64; square++) {
        auto fileIndex = FileFrom(square);
        auto rankIndex = RankFrom(square);
        
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

MoveList MoveGenerator::generateMoves(Board board, Square specificSquare) {
    MoveList moveList;
    
    generatePawnsMoves(board, moveList, specificSquare);
    generateKingsMoves(board, moveList, specificSquare);
    generateKnightsMoves(board, moveList, specificSquare);
    generateSlidingMoves(board, ROOK, moveList, specificSquare);
    generateSlidingMoves(board, BISHOP, moveList, specificSquare);
    generateSlidingMoves(board, QUEEN, moveList, specificSquare);
    
    return moveList;
}

void MoveGenerator::generatePawnsMoves(Board &board, MoveList &moveList, Square specificSquare) {
    auto pawns = board.pieces[board.color][PAWN];
    auto emptySquares = board.emptySquares();
    auto blackPieces = board.allPieces(INVERSE(board.color));
    
    // Generate moves for each white pawn
    while (pawns > 0) {
        // Find the first white pawn starting from the least significant bit (that is, square a1)
        Square square = lsb(pawns);
        
        // If the square index is specified, only generate move for that square
        if (specificSquare != SquareUndefined && square != specificSquare) {
            break;
        }
        
        // Clear that bit so next time we can find the next white pawn
        bb_clear(pawns, square);
        
        // Generate a bitboard for all the attacks that this white pawn
        // can do. The attacks bitboard is masked with the occupancy bitboard
        // because a pawn attack can only happen when there is a black piece
        // in the target square.
        auto attacks = PawnAttacks[board.color][square] & blackPieces;
        if (attacks > 0) {
            moveList.addCaptures(board, square, attacks, PAWN);
        }
        
        // Also check if it's possible to do the en-passant
        if (board.enPassant > 0) {
            auto enPassantMove = PawnAttacks[board.color][square] & board.enPassant;
            if (enPassantMove > 0) {
                auto enPassantToSquare = lsb(enPassantMove);
                moveList.addMove(board, createEnPassant(square, enPassantToSquare, board.color, PAWN));
            }
        }
        
        // Generate the move for the pawn:
        // - Either one square or
        // - Two squares if the pawn is in its initial rank
        Square oneSquareForward, twoSquaresForward;
        Rank initialRank;
        Rank rankBeforePromotion;
        Rank currentRank = RankFrom(square);
        if (board.color == WHITE) {
            if (currentRank == 7) {
                continue; // cannot move anymore, we are on the last rank
            }
            initialRank = 1;
            rankBeforePromotion = 6;
            oneSquareForward = square + 8;
            twoSquaresForward = square + 16;
        } else {
            if (currentRank == 1) {
                continue; // cannot move anymore, we are on the last rank
            }
            initialRank = 6;
            rankBeforePromotion = 1;
            oneSquareForward = square - 8;
            twoSquaresForward = square - 16;
        }
        
        // Can we move the pawn forward one square?
        if (((1UL << oneSquareForward) & emptySquares) > 0) {
            moveList.addMove(board, createMove(square, oneSquareForward, board.color, PAWN));
            
            // Handle promotion in case the pawn reaches the last rank
            if (currentRank == rankBeforePromotion) {
                // Generate one move for each piece that can the pawn can be promoted to.
                moveList.addMove(board, createPromotion(square, oneSquareForward, board.color, PAWN, KNIGHT));
                moveList.addMove(board, createPromotion(square, oneSquareForward, board.color, PAWN, BISHOP));
                moveList.addMove(board, createPromotion(square, oneSquareForward, board.color, PAWN, ROOK));
                moveList.addMove(board, createPromotion(square, oneSquareForward, board.color, PAWN, QUEEN));
            }
            
            // Is pawn on the initial rank? Try two squares forward
            if (currentRank == initialRank && ((1UL << twoSquaresForward) & emptySquares) > 0) {
                moveList.addMove(board, createMove(square, twoSquaresForward, board.color, PAWN));
            }
        }
    }
}

void MoveGenerator::generateKingsMoves(Board &board, MoveList &moveList, Square specificSquare) {
    auto kings = board.pieces[board.color][KING];
    auto emptySquares = board.emptySquares();
    auto blackSquares = board.allPieces(INVERSE(board.color));
    
    // Generate moves for each white knight
    while (kings > 0) {
        // Find the first white knight starting from the least significant bit (that is, square a1)
        Square square = lsb(kings);
        
        // If the square index is specified, only generate move for that square
        if (specificSquare != SquareUndefined && square != specificSquare) {
            break;
        }
        
        // Clear that bit so next time we can find the next white knight
        bb_clear(kings, square);
        
        // Generate a bitboard for all the moves that this white knight
        // can do. The attacks bitboard is masked to ensure it can only
        // happy on an empty square or a square with a piece of the opposite color.
        auto moves = KingMoves[square] & emptySquares;
        moveList.addMoves(board, square, moves, KING);

        auto captures = KingMoves[square] & blackSquares;
        moveList.addCaptures(board, square, captures, KING);
        
    }
}

void MoveGenerator::generateKnightsMoves(Board &board, MoveList &moveList, Square specificSquare) {
    auto whiteKnights = board.pieces[board.color][KNIGHT];
    auto emptySquares = board.emptySquares();
    auto blackSquares = board.allPieces(INVERSE(board.color));

    // Generate moves for each white knight
    while (whiteKnights > 0) {
        // Find the first white knight starting from the least significant bit (that is, square a1)
        Square square = lsb(whiteKnights);
        
        // If the square index is specified, only generate move for that square
        if (specificSquare != SquareUndefined && square != specificSquare) {
            break;
        }
        
        // Clear that bit so next time we can find the next white knight
        bb_clear(whiteKnights, square);
        
        // Generate a bitboard for all the moves that this white knight
        // can do. The attacks bitboard is masked to ensure it can only
        // happy on an empty square or a square with a piece of the opposite color.
        auto moves = KnightMoves[square] & emptySquares;
        moveList.addMoves(board, square, moves, KNIGHT);
        
        auto captures = KnightMoves[square] & blackSquares;
        moveList.addCaptures(board, square, captures, KNIGHT);
    }
}

void MoveGenerator::generateSlidingMoves(Board &board, Piece piece, MoveList &moveList, Square specificSquare) {
    auto slidingPieces = board.pieces[board.color][piece];
    auto occupancy = board.getOccupancy();
    auto emptySquares = board.emptySquares();
    auto blackSquares = board.allPieces(INVERSE(board.color));

    // Generate moves for each sliding piece
    while (slidingPieces > 0) {
        // Find the first sliding piece starting from the least significant bit (that is, square a1)
        Square square = lsb(slidingPieces);
        
        // If the square index is specified, only generate move for that square
        if (specificSquare != SquareUndefined && square != specificSquare) {
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
        auto moves = potentialMoves & emptySquares;
        moveList.addMoves(board, square, moves, piece);
        
        auto captures = potentialMoves & blackSquares;
        moveList.addCaptures(board, square, captures, piece);
    }
}
