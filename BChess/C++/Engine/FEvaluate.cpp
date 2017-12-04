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
                    pieceValue = count * 1;
                    break;
                case ROOK:
                    pieceValue = count * 5;
                    break;
                case BISHOP:
                case KNIGHT:
                    pieceValue = count * 3;
                    break;
                case QUEEN:
                    pieceValue = count * 9;
                    break;
                default:
                    break;
            }
            if (color == WHITE) { // Always evaluate from white point of view!!
                value += pieceValue;
            } else {
                value -= pieceValue;
            }
        }
    }
    
//    std::cout << "Evaluate: " << value << ", color:" << board.color << std::endl;
//    
//    board.print();
    
//    for (piece, coordinate) in board {
//        if piece.isEmpty {
//            continue
//        }
//
//        let locFactor = locationFactor[coordinate.rank*Board.size+coordinate.file]
//        let pieceBonus = piece.type.value * locFactor
//        if piece.color == .white {
//            value += piece.type.value * scorePieceFactor + pieceBonus
//        } else {
//            value -= piece.type.value * scorePieceFactor + pieceBonus
//        }
//    }
    
    // Evaluate the number of pieces being attacked
//    let whiteIsAttacking = board.color == .white
//    for move in moves {
//        let targetSquare = board[move.to]
//
//        // Ignore if the target square is empty
//        guard !targetSquare.isEmpty else {
//            continue
//        }
//
//        // Check that the target square is of the opposite color
//        // Note: the move generator should already do that
//        assert(targetSquare.color != board.color, "Target square should be of the opposite color")
//
//        if targetSquare.type == .king {
//            if whiteIsAttacking {
//                value += checkingBonus
//            } else {
//                value -= checkingBonus
//            }
//        } else {
//            if whiteIsAttacking {
//                value += attackingBonus
//            } else {
//                value -= attackingBonus
//            }
//        }
//    }
    
    return value;
}
