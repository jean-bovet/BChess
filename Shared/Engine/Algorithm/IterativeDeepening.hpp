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
#include "TranspositionTable.hpp"

#include <atomic>
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

class IterativeDeepening {
    
public:
    typedef std::function<void(ChessEvaluation)> SearchCallback;

    MinMaxSearch minMaxSearch;

    TranspositionTable table;

    enum class Status {
        running,
        stopped,
        cancelled
    };
    
    // Written by stop() and cancel() from other threads while search() runs.
    std::atomic<Status> status{Status::stopped};
    
    // The last depth that search() completed, 0 before depth 1 is done.
    std::atomic<int> completedDepth{0};
    
    // Arms the next search(). It is separate from search() so that a stop() or cancel() that arrives
    // before search() begins is honored instead of being overwritten.
    void start() {
        completedDepth = 0;
        minMaxSearch.resume();
        status = Status::running;
    }
    
    // A cancel ends the search at once. A stop always lets depth 1 finish, so the result is a real move,
    // and then ends the search. Only fully completed depths are recorded.
    ChessEvaluation search(ChessBoard board, HistoryPtr history, int maxDepth, SearchCallback callback) {
        if (maxDepth == -1) {
            maxDepth = INT_MAX; // infinite depth
        }
        
        ChessEvaluation evaluation;
        MinMaxSearch::Variation bestVariation;

        for (int curMaxDepth=1; curMaxDepth<=maxDepth; curMaxDepth++) {
            if (cancelled() || (curMaxDepth > 1 && !running())) {
                break;
            }
            
            TimeManagement moveClock;
            moveClock.start();
            
            minMaxSearch.config.maxDepth = curMaxDepth;
            minMaxSearch.reset();
            
            MinMaxSearch::Variation pv;
            
            int score = minMaxSearch.alphabeta(board, history, table, 0, board.color == WHITE, pv, bestVariation);
            
            moveClock.stop();
            
//            int percentCollision = (float)table.collisionCount / table.storeCount * 100;
//            std::cout << "Entry count = " << table.storeCount << ", collision = " << table.collisionCount << " (" << percentCollision << "%)" << ", new = " << table.newStoreCount << std::endl;

            double movesPerSingleMs = minMaxSearch.visitedNodes / moveClock.elapsedMilli();
            int movesPerSecond = int(movesPerSingleMs * 1e3);
            
            if (cancelled()) {
                break;
            }
            
            if (curMaxDepth == 1 || running()) {
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
                
                completedDepth = curMaxDepth;
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
        
        Status expected = Status::running;
        status.compare_exchange_strong(expected, Status::stopped);
        
        return evaluation;
    }
    
    bool running() {
        return status == Status::running;
    }

    bool cancelled() {
        return status == Status::cancelled;
    }

    void stop() {
        status = Status::stopped;
        if (completedDepth > 0) {
            minMaxSearch.cancel();
        }
    }
    
    void cancel() {
        status = Status::cancelled;
        minMaxSearch.cancel();
    }

};
