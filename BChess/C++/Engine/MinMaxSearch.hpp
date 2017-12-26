//
//  FAlphaBeta.hpp
//  BChess
//
//  Created by Jean Bovet on 12/18/17.
//  Copyright © 2017 Jean Bovet. All rights reserved.
//

#pragma once

#include <stdio.h>
#include <climits>
#include <algorithm>
#include <iostream>

#include "MinMaxMoveList.hpp"

struct Configuration {
    int maxDepth = 4;
    bool debugLog = false;
    bool alphaBetaPrunning = true;
    bool quiescenceSearch = true;
    bool sortMoves = true;
};

template <class TMoveList>
struct MinMaxVariation {
    TMoveList moves;
    
    int depth = 0;
    int value = 0;
};

template <class TNode, class TNodeEvaluater, class TMoveGenerator, class TMoveList>
class MinMaxSearch {
    bool analyzing = false;
    
public:
    Configuration config;
    
    int visitedNodes = 0;
    
    void reset() {
        visitedNodes = 0;
    }

    void cancel() {
        analyzing = false;
    }
    
    int alphabeta(TNode node, int depth, bool maximizingPlayer, MinMaxVariation<TMoveList> &pv) {
        analyzing = true;
        MinMaxVariation<TMoveList> currentLine;
        int color = maximizingPlayer ? 1 : -1;
        return alphabeta(node, depth, -INT_MAX, INT_MAX, color, pv, currentLine);
    }
    
private:
    
    // pv: Principal Variation - the best line found so far.
    // cv: Current Variation - the current line being examined.
    int alphabeta(TNode node, int depth, int alpha, int beta, int color, MinMaxVariation<TMoveList> &pv, MinMaxVariation<TMoveList> &cv) {
        pv.depth = depth;

        if (depth == config.maxDepth) {
            if (config.quiescenceSearch) {
                return quiescence(node, depth, alpha, beta, color, pv, cv);
            } else {
                int v = TNodeEvaluater::evaluate(node) * color;
                return v;
            }
        }

        auto moves = TMoveGenerator::generateMoves(node);
        if (config.sortMoves) {
            TMoveGenerator::sortMoves(moves);
        }
        
        bool evaluatedAtLeastOneChild = false; // TODO simplify with moves.empty()?
        int bestValue = -INT_MAX;
        for (int index=0; index<moves.count; index++) {
            auto move = moves.moves[index];
            if (!analyzing) {
                break;
            }
            
            evaluatedAtLeastOneChild = true;
            
            visitedNodes++;

            auto newNode = node;
            newNode.move(move);

            cv.moves.push(move);
            
            MinMaxVariation<TMoveList> line;
            int score = -alphabeta(newNode, depth + 1, -beta, -alpha, -color, line, cv);
            
            cv.moves.pop();
            
            if (score > bestValue) {
                bestValue = score;
                
                pv.depth = line.depth;
                pv.value = score;
                
                pv.moves.count = 0;
                pv.moves.push(move);
                pv.moves.push(line.moves);
            }
            
            alpha = std::max(alpha, score);
            if (config.alphaBetaPrunning && beta <= alpha) {
                break; // Beta cut-off
            }
        }
        if (!evaluatedAtLeastOneChild) {
            bestValue = TNodeEvaluater::evaluate(node, moves) * color;
        }
        return bestValue;
    }
    
    int quiescence(TNode node, int depth, int alpha, int beta, int color, MinMaxVariation<TMoveList> &pv, MinMaxVariation<TMoveList> &cv) {
        pv.depth = depth;
        
        auto stand_pat = TNodeEvaluater::evaluate(node) * color;
        if (stand_pat >= beta) {
            return beta;
        }
        
        if (alpha < stand_pat) {
            alpha = stand_pat;
        }
        
        auto moves = TMoveGenerator::generateMoves(node);
        if (config.sortMoves) {
            TMoveGenerator::sortMoves(moves);
        }
        
        bool atLeastOne = false;  // TODO simplify with moves.empty()?
        
        for (int index=0; index<moves.count; index++) {
            auto move = moves.moves[index];
            if (TNodeEvaluater::isQuiet(move)) {
                continue;
            }
            
            if (!analyzing) {
                break;
            }
            
            atLeastOne = true;
            
            visitedNodes++;
            
            auto newNode = node;
            newNode.move(move);
            
            cv.moves.push(move);
            
            MinMaxVariation<TMoveList> line;
            int score = -quiescence(newNode, depth+1, -beta, -alpha, -color, line, cv);
            
            cv.moves.pop();

            pv.depth = line.depth;
            pv.value = score;
            pv.moves.count = 0;
            pv.moves.push(move);
            pv.moves.push(line.moves);

            if (score >= beta) {
                return beta;
            }
            
            if (score > alpha) {
                alpha = score;
            }
        }
        
//        if (!atLeastOne) {
//            if (currentLine.description() == "d7d5 e4xd5 Nf6xd5 Nc3xd5 Qd8xd5") {
//                int a = 0;
//            }
//            std::cout << currentLine.description() <<std::endl;
//        }
        
        return alpha;
    }
    
};
