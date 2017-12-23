//
//  IterativeDeepening.hpp
//  BChess
//
//  Created by Jean Bovet on 12/22/17.
//  Copyright © 2017 Jean Bovet. All rights reserved.
//

#pragma once

#include "ChessSearch.hpp"
#include "FEvaluate.hpp"

#include <chrono>
using namespace std::chrono;

template<class Node, class MoveGenerator, class Evaluater, class Evaluation>
class IterativeDeepening {
    MinMaxSearch<Node, MoveGenerator, Evaluater, Evaluation> minMaxSearch;
    
    bool analyzing = false;
    
public:
    typedef std::function<void(ChessEvaluation)> SearchCallback;
    
    ChessEvaluation search(Board board, int maxDepth, SearchCallback callback) {
        if (maxDepth == -1) {
            maxDepth = INT_MAX; // infinite depth
        }
        
        ChessEvaluation evaluation;
        
        analyzing = true;
        
        for (int curMaxDepth=1; curMaxDepth<=maxDepth; curMaxDepth++) {
            if (!analyzing) {
                break;
            }
            
            high_resolution_clock::time_point before = high_resolution_clock::now();
            
            minMaxSearch.config.maxDepth = curMaxDepth;
            minMaxSearch.reset();
            evaluation = minMaxSearch.alphabeta(board, 0, board.color == WHITE);
            
            high_resolution_clock::time_point after = high_resolution_clock::now();
            
            duration<double, std::milli> time_span = after - before;
            double diffMs = time_span.count();
            
            double movesPerSingleMs = evaluation.nodes / diffMs;
            int movesPerSecond = int(movesPerSingleMs * 1e3);
            
            evaluation.time = int(diffMs/1e3);
            evaluation.engineColor = board.color;
            evaluation.movesPerSecond = movesPerSecond;
            
            if (callback) {
                callback(evaluation);
            }
        }
        return evaluation;
    }
    
    void cancel() {
        analyzing = false;
        minMaxSearch.cancel();
    }

};
