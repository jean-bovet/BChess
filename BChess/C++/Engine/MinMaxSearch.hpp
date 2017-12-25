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

#define DEBUG_OUTPUT 0

struct Configuration {
    int maxDepth = 4;
    bool debugLog = false;
    bool alphaBetaPrunning = true;
    bool quiescenceSearch = true;
    bool sortMoves = true;
};

template <class Node, class MoveGenerator, class TMove, class Evaluater, class Evaluation>
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
    
    int alphabeta(Node node, int depth, bool maximizingPlayer, Evaluation &pv) {
        analyzing = true;
        return alphabeta(node, depth, -INT_MAX, INT_MAX, maximizingPlayer ? 1 : -1, pv);
    }

private:
    
    int quiescence(Node node, int depth, int alpha, int beta, int color, Evaluation &pv) {
        auto stand_pat = Evaluater::evaluate(node) * color;
        if (stand_pat >= beta) {
            return beta;
        }
        
        if (alpha < stand_pat) {
            alpha = stand_pat;
        }

        auto moves = MoveGenerator::generateMoves(node);
        if (config.sortMoves) {
            MoveGenerator::sortMoves(moves);
        }
        
        for (int index=0; index<moves.count; index++) {
            auto move = moves.moves[index];
            if (Evaluater::isQuiet(move)) {
                continue;
            }
            
            if (!analyzing) {
                pv.cancelled = true;
                break;
            }
            
            visitedNodes++;

            auto newNode = node;
            newNode.move(move);
            auto score = -quiescence(newNode, depth+1, -beta, -alpha, -color, pv);
            if (score >= beta) {
                return beta;
            }
            
            if (score > alpha) {
                alpha = score;
            }
        }
        return alpha;
    }
    
    int alphabeta(Node node, int depth, int alpha, int beta, int color, Evaluation &pv) {
        if (depth == config.maxDepth) {
            if (config.quiescenceSearch) {
                return quiescence(node, depth, alpha, beta, color, pv);
            } else {
                int v = Evaluater::evaluate(node) * color;
                return v;
            }
        }

        auto moves = MoveGenerator::generateMoves(node);
        if (config.sortMoves) {
            MoveGenerator::sortMoves(moves);
        }
        
        bool evaluatedAtLeastOneChild = false;
        Evaluation line;
        int bestValue = -INT_MAX;
        for (int index=0; index<moves.count; index++) {
            auto move = moves.moves[index];
            if (!analyzing) {
                pv.cancelled = true;
                break;
            }
            
            evaluatedAtLeastOneChild = true;
            
            visitedNodes++;

            auto newNode = node;
            newNode.move(move);
            auto score = -alphabeta(newNode, depth + 1, -beta, -alpha, -color, line);
            if (score > bestValue) {
                bestValue = score;
                
                pv.line.moves[0] = move;
                memcpy(pv.line.moves+1, line.line.moves, line.line.count * sizeof(TMove));
                pv.line.count = line.line.count + 1;
            }
            
            alpha = std::max(alpha, score);
            if (config.alphaBetaPrunning && beta <= alpha) {
                break; // Beta cut-off
            }
        }
        if (!evaluatedAtLeastOneChild) {
            bestValue = Evaluater::evaluate(node, moves);
        }
        return bestValue;
    }
    
};
