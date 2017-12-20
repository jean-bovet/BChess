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

static bool initialized = false;

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
    if (!initialized) {
        initialized = true;
        initialize();
    }
    
    MoveList moveList;
    
    generatePawnsMoves(board, moveList, specificSquare);
    generateKingsMoves(board, moveList, specificSquare);
    generateKnightsMoves(board, moveList, specificSquare);
    generateSlidingMoves(board, ROOK, moveList, specificSquare);
    generateSlidingMoves(board, BISHOP, moveList, specificSquare);
    generateSlidingMoves(board, QUEEN, moveList, specificSquare);
    
    return moveList;
}

void MoveGenerator::generateAttackMoves(Board &board, MoveList &moveList, Square fromSquare, Piece attackingPiece, Bitboard attackingSquares) {
    auto attackedColor = INVERSE(board.color);
    for (unsigned capturedPiece = PAWN; capturedPiece < PCOUNT; capturedPiece++) {
        auto attacks = attackingSquares & board.pieces[attackedColor][capturedPiece];
        if (attacks > 0) {
            moveList.addCaptures(board, fromSquare, attacks, attackingPiece, Piece(capturedPiece));
        }
    }
}

void MoveGenerator::generatePawnsMoves(Board &board, MoveList &moveList, Square specificSquare) {
    auto pawns = board.pieces[board.color][PAWN];
    auto emptySquares = board.emptySquares();
    
    // Generate moves for each white pawn
    while (pawns > 0) {
        // Find the first white pawn starting from the least significant bit (that is, square a1)
        Square square = lsb(pawns);
        
        // Clear that bit so next time we can find the next white pawn
        bb_clear(pawns, square);
        
        // If the square index is specified, only generate move for that square
        if (specificSquare != SquareUndefined && square != specificSquare) {
            continue;
        }

        // Generate a bitboard for all the attacks that this white pawn
        // can do. The attacks bitboard is masked with the occupancy bitboard
        // because a pawn attack can only happen when there is a black piece
        // in the target square.
        generateAttackMoves(board, moveList, square, PAWN, PawnAttacks[board.color][square]);
        
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
            if (currentRank == 0) {
                continue; // cannot move anymore, we are on the last rank
            }
            initialRank = 6;
            rankBeforePromotion = 1;
            oneSquareForward = square - 8;
            twoSquaresForward = square - 16;
        }
        
        // Can we move the pawn forward one square?
        if (((1UL << oneSquareForward) & emptySquares) > 0) {
            // Handle promotion in case the pawn reaches the last rank
            if (currentRank == rankBeforePromotion) {
                // Generate one move for each piece that can the pawn can be promoted to.
                moveList.addMove(board, createPromotion(square, oneSquareForward, board.color, PAWN, KNIGHT));
                moveList.addMove(board, createPromotion(square, oneSquareForward, board.color, PAWN, BISHOP));
                moveList.addMove(board, createPromotion(square, oneSquareForward, board.color, PAWN, ROOK));
                moveList.addMove(board, createPromotion(square, oneSquareForward, board.color, PAWN, QUEEN));
            } else {
                moveList.addMove(board, createMove(square, oneSquareForward, board.color, PAWN));
            }
            
            // Is pawn on the initial rank? Try two squares forward
            if (currentRank == initialRank && ((1UL << twoSquaresForward) & emptySquares) > 0) {
                moveList.addMove(board, createMove(square, twoSquaresForward, board.color, PAWN));
            }
        }
    }
}

void MoveGenerator::generateKingsMoves(Board &board, MoveList &moveList, Square specificSquare) {
    auto otherColor = INVERSE(board.color);
    auto kings = board.pieces[board.color][KING];
    auto emptySquares = board.emptySquares();
    
    // Generate moves for each white knight
    while (kings > 0) {
        // Find the first white knight starting from the least significant bit (that is, square a1)
        Square square = lsb(kings);
        
        // Clear that bit so next time we can find the next white knight
        bb_clear(kings, square);

        // If the square index is specified, only generate move for that square
        if (specificSquare != SquareUndefined && square != specificSquare) {
            continue;
        }
        
        // Generate a bitboard for all the moves that this white knight
        // can do. The attacks bitboard is masked to ensure it can only
        // happy on an empty square or a square with a piece of the opposite color.
        auto moves = KingMoves[square] & emptySquares;
        moveList.addMoves(board, square, moves, KING);

        generateAttackMoves(board, moveList, square, KING, KingMoves[square]);
        
        // Generate all legal casting moves. Note that we only generate the move for the king,
        // the board is going to move the rook in move() when it detects a castling move.
        if (board.color == WHITE && square == e1) {
            if (board.whiteCanCastleKingSide) {
                Bitboard kingMoves = 1 << (square+1) | 1 << (square+2);
                if ((kingMoves & emptySquares) == kingMoves && !board.isAttacked(square+1, otherColor) && !board.isAttacked(square+2, otherColor)) {
                    moveList.addMove(board, createMove(square, square+2, board.color, KING));
                }
            }
            if (board.whiteCanCastleQueenSide) {
                Bitboard kingMoves = 1 << (square-1) | 1 << (square-2) | 1 << (square-3);
                if ((kingMoves & emptySquares) == kingMoves && !board.isAttacked(square-1, otherColor) && !board.isAttacked(square-2, otherColor) && !board.isAttacked(square-3, otherColor)) {
                    moveList.addMove(board, createMove(square, square-2, board.color, KING));
                }
            }
        }
        if (board.color == BLACK && square == e8) {
            if (board.blackCanCastleKingSide) {
                Bitboard kingMoves = 1UL << (square+1) | 1UL << (square+2);
                if ((kingMoves & emptySquares) == kingMoves && !board.isAttacked(square+1, otherColor) && !board.isAttacked(square+2, otherColor)) {
                    moveList.addMove(board, createMove(square, square+2, board.color, KING));
                }
            }
            if (board.blackCanCastleQueenSide) {
                Bitboard kingMoves = 1UL << (square-1) | 1UL << (square-2) | 1UL << (square-3);
                if ((kingMoves & emptySquares) == kingMoves && !board.isAttacked(square-1, otherColor) && !board.isAttacked(square-2, otherColor) && !board.isAttacked(square-3, otherColor)) {
                    moveList.addMove(board, createMove(square, square-2, board.color, KING));
                }
            }
        }
    }
}

void MoveGenerator::generateKnightsMoves(Board &board, MoveList &moveList, Square specificSquare) {
    auto whiteKnights = board.pieces[board.color][KNIGHT];
    auto emptySquares = board.emptySquares();

    // Generate moves for each white knight
    while (whiteKnights > 0) {
        // Find the first white knight starting from the least significant bit (that is, square a1)
        Square square = lsb(whiteKnights);
        
        // Clear that bit so next time we can find the next white knight
        bb_clear(whiteKnights, square);

        // If the square index is specified, only generate move for that square
        if (specificSquare != SquareUndefined && square != specificSquare) {
            continue;
        }
        
        // Generate a bitboard for all the moves that this white knight
        // can do. The attacks bitboard is masked to ensure it can only
        // happy on an empty square or a square with a piece of the opposite color.
        auto moves = KnightMoves[square] & emptySquares;
        moveList.addMoves(board, square, moves, KNIGHT);
        
        generateAttackMoves(board, moveList, square, KNIGHT, KnightMoves[square]);
    }
}

void MoveGenerator::generateSlidingMoves(Board &board, Piece piece, MoveList &moveList, Square specificSquare) {
    auto slidingPieces = board.pieces[board.color][piece];
    auto occupancy = board.getOccupancy();
    auto emptySquares = board.emptySquares();

    // Generate moves for each sliding piece
    while (slidingPieces > 0) {
        // Find the first sliding piece starting from the least significant bit (that is, square a1)
        Square square = lsb(slidingPieces);
        
        // Clear that bit so next time we can find the next sliding piece
        bb_clear(slidingPieces, square);
        
        // If the square index is specified, only generate move for that square
        if (specificSquare != SquareUndefined && square != specificSquare) {
            continue;
        }

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
        
        generateAttackMoves(board, moveList, square, piece, potentialMoves);
    }
}
