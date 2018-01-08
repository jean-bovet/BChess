//
//  FEvaluate.cpp
//  BChess
//
//  Created by Jean Bovet on 12/3/17.
//  Copyright © 2017 Jean Bovet. All rights reserved.
//

#include "ChessEvaluater.hpp"
#include "ChessMoveGenerator.hpp"
#include "ChessBoard.hpp"
#include "GameHistory.hpp"

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

static Square whiteIndex(Square original) {
    auto rank = RankFrom(original);
    auto file = FileFrom(original);
    return (7-rank)*8+file;
}

static Square blackIndex(Square original) {
    auto rank = RankFrom(original);
    auto file = FileFrom(original);
    return rank*8+file;
}

bool ChessEvaluater::isQuiet(Move move) {
    // A quiet move is a move that is not:
    // - a capture
    // - a promotion
    // - a check
    return !MOVE_IS_CAPTURE(move) && MOVE_PROMOTION_PIECE(move) == 0 && !MOVE_IS_CHECK(move);
}

int ChessEvaluater::getBonus(Piece piece, Color color, Square square) {
    auto index = color == WHITE ? whiteIndex(square) : blackIndex(square);
    switch (piece) {
        case PAWN:
            return PawnPositionBonus[index];
            
        case BISHOP:
            return BishopPositionBonus[index];
            
        case KNIGHT:
            return KnightPositionBonus[index];
            
        case ROOK:
            return RookPositionBonus[index];
            
        case KING:
            return KingPositionBonus[index];
            
        case QUEEN:
            return QueenPositionBonus[index];
            
        default:
            return 0;
    }
}

bool ChessEvaluater::isDraw(ChessBoard board, HistoryPtr history) {
    return ChessHistory::isThreefoldRepetition(board.hash(), history);
}

int ChessEvaluater::evaluate(ChessBoard board, HistoryPtr history) {
    auto moves = ChessMoveGenerator::generateMoves(board, board.color, ChessMoveGenerator::Mode::moveCaptureAndDefenseMoves);
    return evaluate(board, history, moves);
}

static int PieceActionValue[PCOUNT] = { 6, 3, 3, 2, 1, 1 };

int ChessEvaluater::evaluate(ChessBoard board, HistoryPtr history, ChessMoveList moves) {
    if (moves.count == 0) {
        if (board.isCheck(board.color)) {
            // No moves but a check, that's a mat
            // Note: always evaluate from white's point of view
            return -MAT_VALUE;
        } else {
            // No moves and not check, that's a draw
            return 0;
        }
    }
    
    // Check for threefold repetition
    if (isDraw(board, history)) {
        // It's a draw if the repetition is detected
        return 0;
    }
    
    // Compute the piece balance value
    int value = 0;
    for (unsigned color=0; color<COUNT; color++) {
        // Note: always evaluate from white's point of view
        int colorSign = (color == WHITE) ? 1 : -1;
        
        // The bonus of the pieces' locations, for that particular color
        int totalBonus = 0;
        for (unsigned piece=0; piece<PCOUNT; piece++) {
            Bitboard pieces = board.pieces[color][piece];
            int count = bb_count(pieces);
            int pvalue = PieceValue[piece];

            value += colorSign * (pvalue * count);
            
            // Advantage when a pair of bishop is detected, which is worth 1/2 pawn
            // https://www.chess.com/article/view/the-evaluation-of-material-imbalances-by-im-larry-kaufman
            if (piece == BISHOP && count >= 2) {
                value += color * (PieceValue[PAWN]/2);
            }
            
            // Now let's add some bonus depending on the piece location
            while (pieces > 0) {
                Square square = lsb(pieces);
                bb_clear(pieces, square);
                
                totalBonus += getBonus((Piece)piece, (Color)color, square);
            }
        }
        
        value += colorSign * totalBonus;
    }
    
    // Compute the piece action value (either attacked, defended or hanging)
//    value += evaluateActionAndMobility(board.color, moves);
    
    return value;
}

int ChessEvaluater::evaluateAction(Color color, ChessMoveList moves) {
    int attackedValues[2][64] = { };
    int defendedValues[2][64] = { };
    
    for (int index=0; index<moves.count; index++) {
        auto move = moves[index];
        auto moveColor = MOVE_COLOR(move);
        
        if (MOVE_IS_CAPTURE(move)) {
            auto to = MOVE_TO(move);
            if (MOVE_CAPTURED_PIECE_COLOR(move) == MOVE_COLOR(move)) {
                // Same color, means defense. Doesn't count towards
                // mobility because in reality that piece cannot move.
                defendedValues[moveColor][to]++;
            } else {
                // Different color means capture.
                // This count also towards mobility.
                attackedValues[INVERSE(moveColor)][to]++;
            }
        }
    }
    
    int value = 0;
    
    for (int index=0; index<64; index++) {
        for (unsigned color=0; color<COUNT; color++) {
            auto colorSign = (color == WHITE) ? 1 : -1;
            
            auto attacked = attackedValues[color][index];
            auto defended = defendedValues[color][index];
            
            value -= colorSign * attacked;
            value += colorSign * defended;
            
            if (defended < attacked) {
                value -= colorSign * ((attacked - defended) * 10);
            }
        }
    }
        
    return value;
}

int ChessEvaluater::evaluateMobility(Color color2, ChessMoveList moves) {
    int mobility = 0;
    
    for (int index=0; index<moves.count; index++) {
        auto move = moves[index];
        auto moveColor = MOVE_COLOR(move);
        auto whiteMove = moveColor == WHITE;
        auto colorSign = whiteMove ? 1 : -1;
        
        if (MOVE_IS_CAPTURE(move)) {
            if (MOVE_CAPTURED_PIECE_COLOR(move) != MOVE_COLOR(move)) {
                // Different color means capture.
                // This count also towards mobility.
                mobility += colorSign * 1;
            }
        } else {
            // Regular move, just count towards mobility
            mobility += colorSign * 1;
            
            // One more bonus when castling because two pieces are moving
            if (MOVE_IS_CASTLING(move)) {
                mobility += colorSign * 1;
            }
        }
    }
    
    return mobility;
}
