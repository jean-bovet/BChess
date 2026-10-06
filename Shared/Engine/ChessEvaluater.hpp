//
//  FEvaluate.hpp
//  BChess
//
//  Created by Jean Bovet on 12/3/17.
//  Copyright © 2017 Jean Bovet. All rights reserved.
//

#pragma once

#include "ChessBoard.hpp"
#include "MoveList.hpp"
#include <climits>

// https://chessprogramming.wikispaces.com/Evaluation
class ChessEvaluater {
public:
    // Mat value which must be lower than INT_MIN or INT_MAX
    // otherwise it causes issue with the min-max algorithm
    // when rewinding (only the first move is registered, not
    // the line of moves to the mat).
    static const int MAT_VALUE = 100000;
    
    // The search scores a mate MAT_VALUE minus the number of plies to it, so that the shorter mate wins.
    // No other score comes anywhere near.
    static const int MAX_MATE_PLY = 1000;
    
    static bool isMateScore(int value) {
        return value > MAT_VALUE - MAX_MATE_PLY || value < -(MAT_VALUE - MAX_MATE_PLY);
    }
    
    // The number of plies to the mate that a mate score stands for, 0 for any other score
    static int matePlies(int value) {
        return isMateScore(value) ? MAT_VALUE - (value < 0 ? -value : value) : 0;
    }
    
    // The material value of a piece, in centipawns
    static int pieceValue(Piece piece);
    
    static bool positionalAnalysis;
    
    static bool isQuiet(Move move);    
    // Threefold repetition: the board's own count of reversible plies bounds the scan of the history
    static bool isDraw(ChessBoard &board, const HistoryPtr &history);

    // The board is not const because generateMoves, isCheck and getHash update its caches
    // The score of the position, from White's point of view. A mate or a stalemate is told by the moves. A
    // repetition is not: the search checks it once per node, before it gets here.
    static int evaluate(ChessBoard &board);
    static int evaluate(ChessBoard &board, const MoveList &moves);

    static int evaluateAction(ChessBoard board);
    static int evaluateMobility(ChessBoard board);

    static int getBonus(Piece piece, Color color, Square square);
    
private:
    static int evaluateAction(const MoveList &moves);
    static int evaluateMobility(const MoveList &moves);
};
