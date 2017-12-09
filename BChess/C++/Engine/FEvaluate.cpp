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

// All these numbers are taken from https://chessprogramming.wikispaces.com/Simplified+evaluation+function
static int PawnPositionBonus[64] = {
    0,  0,  0,  0,  0,  0,  0,  0,
    50, 50, 50, 50, 50, 50, 50, 50,
    10, 10, 20, 30, 30, 20, 10, 10,
    5,  5, 10, 25, 25, 10,  5,  5,
    0,  0,  0, 20, 20,  0,  0,  0,
    5, -5,-10,  0,  0,-10, -5,  5,
    5, 10, 10,-20,-20, 10, 10,  5,
    0,  0,  0,  0,  0,  0,  0,  0
};

static int KnightPositionBonus[64] = {
    -50,-40,-30,-30,-30,-30,-40,-50,
    -40,-20,  0,  0,  0,  0,-20,-40,
    -30,  0, 10, 15, 15, 10,  0,-30,
    -30,  5, 15, 20, 20, 15,  5,-30,
    -30,  0, 15, 20, 20, 15,  0,-30,
    -30,  5, 10, 15, 15, 10,  5,-30,
    -40,-20,  0,  5,  5,  0,-20,-40,
    -50,-40,-30,-30,-30,-30,-40,-50,
};

static int BishopPositionBonus[64] = {
    -20,-10,-10,-10,-10,-10,-10,-20,
    -10,  0,  0,  0,  0,  0,  0,-10,
    -10,  0,  5, 10, 10,  5,  0,-10,
    -10,  5,  5, 10, 10,  5,  5,-10,
    -10,  0, 10, 10, 10, 10,  0,-10,
    -10, 10, 10, 10, 10, 10, 10,-10,
    -10,  5,  0,  0,  0,  0,  5,-10,
    -20,-10,-10,-10,-10,-10,-10,-20,
};

static int RookPositionBonus[64] = {
    0,  0,  0,  0,  0,  0,  0,  0,
    5, 10, 10, 10, 10, 10, 10,  5,
    -5,  0,  0,  0,  0,  0,  0, -5,
    -5,  0,  0,  0,  0,  0,  0, -5,
    -5,  0,  0,  0,  0,  0,  0, -5,
    -5,  0,  0,  0,  0,  0,  0, -5,
    -5,  0,  0,  0,  0,  0,  0, -5,
    0,  0,  0,  5,  5,  0,  0,  0
};

static int QueenPositionBonus[64] = {
    -20,-10,-10, -5, -5,-10,-10,-20,
    -10,  0,  0,  0,  0,  0,  0,-10,
    -10,  0,  5,  5,  5,  5,  0,-10,
    -5,  0,  5,  5,  5,  5,  0, -5,
    0,  0,  5,  5,  5,  5,  0, -5,
    -10,  5,  5,  5,  5,  5,  0,-10,
    -10,  0,  5,  0,  0,  0,  0,-10,
    -20,-10,-10, -5, -5,-10,-10,-20
};

// TODO: see wiki to implement the end game position bonus for king
static int KingPositionBonus[64] = {
    -30,-40,-40,-50,-50,-40,-40,-30,
    -30,-40,-40,-50,-50,-40,-40,-30,
    -30,-40,-40,-50,-50,-40,-40,-30,
    -30,-40,-40,-50,-50,-40,-40,-30,
    -20,-30,-30,-40,-40,-30,-30,-20,
    -10,-20,-20,-20,-20,-20,-20,-10,
    20, 20,  0,  0,  0,  0, 20, 20,
    20, 30, 10,  0,  0, 10, 30, 20
};

static int PieceValue[PCOUNT] = { 100, 320, 330, 500, 900, 20000 };

int Evaluate::evaluate(Board board) {
    // TODO: how to detect a draw?
    // Note: the value should always be computed from a white point of view
    int value = 0;
    for (int color=0; color<COUNT; color++) {
        auto isWhite = color == WHITE;
        for (int piece=0; piece<PCOUNT; piece++) {
            Bitboard pieces = board.pieces[color][piece];
            int count = bb_count(pieces);
            int pvalue = PieceValue[piece];
            
            if (isWhite) { // Always evaluate from white point of view!!
                value += pvalue * count;
            } else {
                value -= pvalue * count;
            }
            
            // Now let's add some bonus depending on the piece location
            while (pieces > 0) {
                int square = lsb(pieces);
                bb_clear(pieces, square);
                
                int bonus = 0;
                int squareIndex = isWhite ? 63-square : square;
                switch (piece) {
                    case PAWN:
                        bonus = PawnPositionBonus[squareIndex];
                        break;
                        
                    case KNIGHT:
                        bonus = KnightPositionBonus[squareIndex];
                        break;

                    case BISHOP:
                        bonus = BishopPositionBonus[squareIndex];
                        break;

                    case ROOK:
                        bonus = RookPositionBonus[squareIndex];
                        break;

                    case QUEEN:
                        bonus = QueenPositionBonus[squareIndex];
                        break;

                    case KING:
                        bonus = KingPositionBonus[squareIndex];
                        break;

                    default:
                        break;
                }
                if (isWhite) { // Always evaluate from white point of view!!
                    value += bonus;
                } else {
                    value -= bonus;
                }
            }
        }
    }

//    auto occupancy = board.getOccupancy();
//
//    for (int color=0; color<COUNT; color++) {
//        auto otherPieces = board.allPieces(INVERSE(color));
//        for (int piece=0; piece<PCOUNT; piece++) {
//            // For each piece on the board, count the number of pieces from the opposite
//            // it is attacking.
//            auto pieces = board.pieces[color][piece];
//
//            // Generate moves for each of piece
//            while (pieces > 0) {
//                // Find the first piece starting from the least significant bit (that is, square a1)
//                int square = lsb(pieces);
//
//                // Clear that bit so next time we can find the next piece
//                bb_clear(pieces, square);
//
//                // Generate a bitboard for all the moves that this piece
//                // can do. The attacks bitboard is masked to ensure it can only
//                // happy on an empty square or a square with a piece of the opposite color.
//                Bitboard attacks = 0;
//                switch (piece) {
//                    case PAWN:
//                        attacks = PawnAttacks[color][piece];
//                        break;
//
//                    case KING:
//                        attacks = KingMoves[piece];
//                        break;
//
//                    case KNIGHT:
//                        attacks = KnightMoves[piece];
//                        break;
//
//                    case BISHOP:
//                        attacks = Bmagic(square, occupancy);
//                        break;
//
//                    case ROOK:
//                        attacks = Rmagic(square, occupancy);
//                        break;
//
//                    case QUEEN:
//                        attacks = Rmagic(square, occupancy)|Bmagic(square, occupancy);
//                        break;
//                }
//
//                auto attackedPieces = attacks & otherPieces;
//                if (attackedPieces == 0) {
//                    continue;
//                }
//
//                // Check if the opposite king is under attack
//                bool check = attacks & board.pieces[INVERSE(color)][KING];
//
//                auto attackCount = bb_count(attackedPieces);
//                if (color == WHITE) { // Always evaluate from white point of view!!
//                    value += attackCount * attackingBonus;
//                    if (check) {
//                        value += checkingBonus;
//                    }
//                } else {
//                    value -= attackCount * attackingBonus;
//                    if (check) {
//                        value -= checkingBonus;
//                    }
//                }
//            }
//        }
//    }
    
    return value;
}
