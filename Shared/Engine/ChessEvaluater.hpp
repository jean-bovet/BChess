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
    
    static bool positionalAnalysis;
    
    static bool isQuiet(Move move);    
    static bool isDraw(ChessBoard board, HistoryPtr history);

    // The board is not const because generateMoves, isCheck and getHash update its caches
    static int evaluate(ChessBoard &board, HistoryPtr history);
    static int evaluate(ChessBoard &board, HistoryPtr history, const MoveList &moves);

    static int evaluateAction(ChessBoard board);
    static int evaluateMobility(ChessBoard board);

    static int getBonus(Piece piece, Color color, Square square);
    
private:
    static int evaluateAction(const MoveList &moves);
    static int evaluateMobility(const MoveList &moves);
};
