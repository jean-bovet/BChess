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

// https://chessprogramming.wikispaces.com/Evaluation
class ChessEvaluater {
public:
    // Mat value which must be lower than INT_MIN or INT_MAX
    // otherwise it causes issue with the min-max algorithm
    // when rewinding (only the first move is registered, not
    // the line of moves to the mat).
    static const int MAT_VALUE = 100000;
    
    static bool positionalAnalysis;
    
    static bool isQuiet(Move move);    
    static bool isDraw(ChessBoard board, HistoryPtr history);

    static int evaluate(ChessBoard board, HistoryPtr history);
    static int evaluate(ChessBoard board, HistoryPtr history, MoveList moves);

    static int evaluateAction(ChessBoard board);
    static int evaluateMobility(ChessBoard board);

    static int getBonus(Piece piece, Color color, Square square);
    
private:
    static int evaluateAction(MoveList moves);
    static int evaluateMobility(MoveList moves);
};
