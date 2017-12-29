//
//  IterativeDeepening.hpp
//  BChess
//
//  Created by Jean Bovet on 12/22/17.
//  Copyright © 2017 Jean Bovet. All rights reserved.
//

#pragma once

#include "ChessEvaluation.hpp"
#include "ChessEvaluater.hpp"

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

template<class Node, class MoveGenerator, class TMoveList, class Evaluater>
class IterativeDeepening {
    ChessMinMaxSearch minMaxSearch;
    
    bool analyzing = false;
    
public:
    typedef std::function<void(ChessEvaluation)> SearchCallback;
    
    ChessEvaluation search(ChessBoard board, int maxDepth, SearchCallback callback) {
        if (maxDepth == -1) {
            maxDepth = INT_MAX; // infinite depth
        }
        
        ChessEvaluation evaluation;
        ChessMinMaxSearch::Variation bestVariation;

        analyzing = true;
        
        for (int curMaxDepth=1; curMaxDepth<=maxDepth; curMaxDepth++) {
            if (!analyzing) {
                break;
            }
            
            TimeManagement moveClock;
            moveClock.start();
            
            minMaxSearch.config.maxDepth = curMaxDepth;
            minMaxSearch.reset();
            
            ChessMinMaxSearch::Variation pv;
            int score = minMaxSearch.alphabeta(board, 0, board.color == WHITE, pv, bestVariation);
            
            moveClock.stop();
            
            double movesPerSingleMs = minMaxSearch.visitedNodes / moveClock.elapsedMilli();
            int movesPerSecond = int(movesPerSingleMs * 1e3);
            
            if (analyzing) {
                bestVariation = pv;
                
                evaluation.clear();
                
                evaluation.value = score;

                evaluation.depth = pv.depth;
                evaluation.quiescenceDepth = pv.qsDepth;

                evaluation.line.push(pv.moves);
                
                evaluation.nodes = minMaxSearch.visitedNodes;
                evaluation.time = int(moveClock.elapsedMilli()/1e3);
                evaluation.engineColor = board.color;
                evaluation.movesPerSecond = movesPerSecond;
            }
            
            if (callback) {
                callback(evaluation);
            }
            
            // If the principal variation has no valid move, it means
            // the current position is stale or mate so no need to continue.
            if (pv.moves.count == 0) {
                break;
            }
        }
        return evaluation;
    }
    
    void cancel() {
        analyzing = false;
        minMaxSearch.cancel();
    }

};
