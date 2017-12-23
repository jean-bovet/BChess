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

class TimeManagement {
private:
    high_resolution_clock::time_point startTime;
    high_resolution_clock::time_point stopTime;
    
public:
    void start() {
        startTime = high_resolution_clock::now();
    }
    
    void stop() {
        stopTime = high_resolution_clock::now();
    }
    
    double elapsedMilli() {
        duration<double, std::milli> time_span = stopTime - startTime;
        double diffMs = time_span.count();
        return diffMs;
    }
};

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
                        
            TimeManagement moveClock;
            moveClock.start();
            
            minMaxSearch.config.maxDepth = curMaxDepth;
            minMaxSearch.reset();
            evaluation = minMaxSearch.alphabeta(board, 0, board.color == WHITE);
            
            moveClock.stop();
            
            double movesPerSingleMs = evaluation.nodes / moveClock.elapsedMilli();
            int movesPerSecond = int(movesPerSingleMs * 1e3);
            
            evaluation.time = int(moveClock.elapsedMilli()/1e3);
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
