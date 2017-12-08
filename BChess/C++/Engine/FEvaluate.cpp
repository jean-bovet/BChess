//
//  FEvaluate.cpp
//  BChess
//
//  Created by Jean Bovet on 12/3/17.
//  Copyright © 2017 Jean Bovet. All rights reserved.
//

#include "FEvaluate.hpp"
#include "FMoveGenerator.hpp"
#include "FBoard.hpp"
#include "magicmoves.h"

#include <iostream>

static int scoreMat = 90000;

static int scorePieceFactor = 100; // Pawn=100, Queen=900

// Bonus for each piece that is attacking or being attacked
static int attackingBonus = 50;

// Bonus each time the king is in check
static int checkingBonus = 100;

static int locationFactor[64] = {
                                    0,  0,  0,  0,  0,  0,  0,  0,
                                    0,  0,  0,  0,  0,  0,  0,  0,
                                    0,  0,  2,  2,  2,  2,  0,  0,
                                    0,  0,  2,  3,  3,  2,  0,  0,
                                    0,  0,  2,  3,  3,  2,  0,  0,
                                    0,  0,  2,  2,  2,  2,  0,  0,
                                    0,  0,  0,  0,  0,  0,  0,  0,
                                    0,  0,  0,  0,  0,  0,  0,  0,
};

int Evaluate::evaluate(Board board) {
    // TODO: need to initialize it each time???
    MoveGenerator generator;
    MoveList moves = generator.generateMoves(board);
    return evaluate(board, moves);
}

int Evaluate::evaluate(Board board, MoveList moves) {
    // Check for mate or draw if there are no moves for this position
    if (moves.moveCount == 0) {
        if (board.isCheck(board.color)) {
            return board.color == WHITE ? -scoreMat : scoreMat;
        } else {
            // TODO Good value to return?
            return 0;
        }
    }
    
    // Note: the value should always be computed from a white point of view
    int value = 0;
    for (int color=0; color<COUNT; color++) {
        for (int piece=0; piece<PCOUNT; piece++) {
            Bitboard pieces = board.pieces[color][piece];
            int count = bb_count(pieces);
            int pieceValue = 0;
            switch (Piece(piece)) {
                case PAWN:
                    pieceValue = 1;
                    break;
                case ROOK:
                    pieceValue = 5;
                    break;
                case BISHOP:
                case KNIGHT:
                    pieceValue = 3;
                    break;
                case QUEEN:
                    pieceValue = 9;
                    break;
                default:
                    break;
            }

            if (color == WHITE) { // Always evaluate from white point of view!!
                value += pieceValue * count * scorePieceFactor;
            } else {
                value -= pieceValue * count * scorePieceFactor;
            }
            
            // Now let's add some bonus for each piece that are closer
            // to the center of the board.
            // TODO: should only do that during openings and mid game?
            while (pieces > 0) {
                int square = lsb(pieces);
                bb_clear(pieces, square);
                auto locFactor = locationFactor[square];
                auto pieceBonus = pieceValue * locFactor;
                if (color == WHITE) { // Always evaluate from white point of view!!
                    value += pieceBonus;
                } else {
                    value -= pieceBonus;
                }
            }
        }
    }

    auto occupancy = board.getOccupancy();

    for (int color=0; color<COUNT; color++) {
        auto otherPieces = board.allPieces(INVERSE(color));
        for (int piece=0; piece<PCOUNT; piece++) {
            // For each piece on the board, count the number of pieces from the opposite
            // it is attacking.
            auto pieces = board.pieces[color][piece];
            
            // Generate moves for each of piece
            while (pieces > 0) {
                // Find the first piece starting from the least significant bit (that is, square a1)
                int square = lsb(pieces);
                
                // Clear that bit so next time we can find the next piece
                bb_clear(pieces, square);
                
                // Generate a bitboard for all the moves that this piece
                // can do. The attacks bitboard is masked to ensure it can only
                // happy on an empty square or a square with a piece of the opposite color.
                Bitboard attacks = 0;
                switch (piece) {
                    case PAWN:
                        attacks = PawnAttacks[color][piece];
                        break;
                        
                    case KING:
                        attacks = KingMoves[piece];
                        break;
                        
                    case KNIGHT:
                        attacks = KnightMoves[piece];
                        break;
                        
                    case BISHOP:
                        attacks = Bmagic(square, occupancy);
                        break;
                        
                    case ROOK:
                        attacks = Rmagic(square, occupancy);
                        break;
                        
                    case QUEEN:
                        attacks = Rmagic(square, occupancy)|Bmagic(square, occupancy);
                        break;
                }
                
                auto attackedPieces = attacks & otherPieces;
                if (attackedPieces == 0) {
                    continue;
                }
                
                // Check if the opposite king is under attack
                bool check = attacks & board.pieces[INVERSE(color)][KING];
                
                auto attackCount = bb_count(attackedPieces);
                if (color == WHITE) { // Always evaluate from white point of view!!
                    value += attackCount * attackingBonus;
                    if (check) {
                        value += checkingBonus;
                    }
                } else {
                    value -= attackCount * attackingBonus;
                    if (check) {
                        value -= checkingBonus;
                    }
                }
            }
        }
    }
        
    return value;
}
