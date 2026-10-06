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

#include <algorithm>
#include <atomic>
#include <chrono>
#include <climits>
#include <functional>
#include <iostream>
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
    
    // Nodes per second, 0 when no time has elapsed
    static int64_t nodesPerSecond(int64_t nodes, int64_t milliseconds) {
        return milliseconds > 0 ? nodes * 1000 / milliseconds : 0;
    }
    
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
        
        // One clock and one node count for the whole search, so that the figures add up over the depths
        TimeManagement searchClock;
        searchClock.start();
        int64_t totalNodes = 0;
        int64_t deepestPly = 0;
        auto elapsedMilli = [&searchClock] {
            searchClock.stop();
            return int64_t(searchClock.elapsedMilli());
        };

        for (int curMaxDepth=1; curMaxDepth<=maxDepth; curMaxDepth++) {
            if (cancelled() || (curMaxDepth > 1 && !running())) {
                break;
            }
            
            minMaxSearch.config.maxDepth = curMaxDepth;
            minMaxSearch.reset();
            
            MinMaxSearch::Variation pv;
            
            int score = minMaxSearch.alphabeta(board, history, table, 0, board.color == WHITE, pv, bestVariation);
            
            totalNodes += minMaxSearch.visitedNodes;
            deepestPly = std::max(deepestPly, minMaxSearch.maxPly);
            
//            int percentCollision = (float)table.collisionCount / table.storeCount * 100;
//            std::cout << "Entry count = " << table.storeCount << ", collision = " << table.collisionCount << " (" << percentCollision << "%)" << ", new = " << table.newStoreCount << std::endl;

            if (cancelled()) {
                break;
            }
            
            // A depth that was interrupted holds a partial result: nothing is recorded or reported for it
            if (curMaxDepth == 1 || running()) {
                bestVariation = pv;
                
                evaluation.clear();
                
                evaluation.value = score;

                // The depth that was searched: a line that ends early (a mate) is shorter than that
                evaluation.depth = curMaxDepth;
                evaluation.quiescenceDepth = pv.qsDepth;
                evaluation.selDepth = int(deepestPly);

                evaluation.line.push(pv.moves);
                
                evaluation.nodes = totalNodes;
                evaluation.time = elapsedMilli();
                evaluation.engineColor = board.color;
                evaluation.movesPerSecond = nodesPerSecond(evaluation.nodes, evaluation.time);
                
                completedDepth = curMaxDepth;
                
                if (callback) {
                    callback(evaluation);
                }
            }
            
            // If the principal variation has no valid move, it means
            // the current position is stale or mate so no need to continue.
            if (pv.moves.count == 0) {
                break;
            }
        }
        
        // The returned evaluation keeps the score and the line of the last completed depth, but its
        // totals cover all the work, including a depth that was interrupted
        evaluation.nodes = totalNodes;
        evaluation.selDepth = int(deepestPly);
        evaluation.time = elapsedMilli();
        evaluation.movesPerSecond = nodesPerSecond(evaluation.nodes, evaluation.time);
        
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
