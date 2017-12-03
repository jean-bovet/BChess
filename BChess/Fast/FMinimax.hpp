//
//  FMinimax.hpp
//  BChess
//
//  Created by Jean Bovet on 12/3/17.
//  Copyright © 2017 Jean Bovet. All rights reserved.
//

#pragma once

#include "FBoard.hpp"
#include <vector>

typedef std::vector<Move> LineMove;

class Minimax {
public:
    int evaluateCount = 0;
    bool analyzing = false;
    
    struct Evaluation {
        Move move;
        int value = 0;
        LineMove line;

        bool isValid() {
            return move.isValid();
        }
        
//        var description: String {
//            return "\(move)[\(value)]"
//        }
//
//        var lineInfo: String {
//            return line.map { $0.description }.joined(separator: " ")
//        }
    };
    
    struct Info {
        int depth = 0;
        int time = 0;
        Evaluation evaluation;
        int nodeEvaluated = 0;
        int movesPerSecond = 0;
    };
    
    Info searchBestMove(Board board, Color color, int maxDepth);

    Evaluation evaluate(Board board, Move move, Color color, int depth, int maxDepth, bool maximizing, LineMove line, int alpha, int beta);

    bool evaluateAlphaBeta(Board board, Move move, Color color, int depth, int maxDepth, bool maximizing, LineMove line, int &alpha, int &beta, Evaluation &bestEvaluation);

};
