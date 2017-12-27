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

template <class TMoveList, class TMove>
struct MinMaxVariation {
    TMoveList moves;
    
    int depth = 0;
    int qsDepth = 0;
    
    int value = 0;

    void push(int score, TMove move, MinMaxVariation<TMoveList, TMove> line) {
        value = score;
        
        depth = std::max(depth, line.depth);
        qsDepth = line.qsDepth;
        
        moves.count = 0;
        moves.push(move);
        moves.push(line.moves);
    }

};

template <class TNode, class TNodeEvaluater, class TMoveGenerator, class TMoveList, class TMove>
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
    
    typedef MinMaxVariation<TMoveList, TMove> Variation;
    
    int alphabeta(TNode node, int depth, bool maximizingPlayer, Variation &pv) {
        analyzing = true;
        Variation currentLine;
        int color = maximizingPlayer ? 1 : -1;
        int score = alphabeta(node, depth, -INT_MAX, INT_MAX, color, pv, currentLine);
        return score * color;
    }
    
private:
    
    // pv: Principal Variation - the best line found so far.
    // cv: Current Variation - the current line being examined.
    // https://en.wikipedia.org/wiki/Negamax
    // https://chessprogramming.wikispaces.com/Principal+variation
    int alphabeta(TNode node, int depth, int alpha, int beta, int color, Variation &pv, Variation &cv) {
        pv.depth = depth;

        if (depth == config.maxDepth) {
            if (config.quiescenceSearch) {
                return quiescence(node, depth, alpha, beta, color, pv, cv);
            } else {
                int score = TNodeEvaluater::evaluate(node) * color;
                return score;
            }
        }

        auto moves = TMoveGenerator::generateMoves(node);
        if (moves.count == 0) {
            int score = TNodeEvaluater::evaluate(node, moves) * color;
            return score;
        }
        
        if (config.sortMoves) {
            TMoveGenerator::sortMoves(moves);
        }
        
        int bestValue = -INT_MAX;
        for (int index=0; index<moves.count && analyzing; index++) {
            visitedNodes++;
            
            auto move = moves.moves[index];
            
            cv.moves.push(move);

            auto newNode = node;
            newNode.move(move);
            
            Variation line;
            int score = -alphabeta(newNode, depth + 1, -beta, -alpha, -color, line, cv);
            
            cv.moves.pop();
            
            if (score > bestValue) {
                bestValue = score;
            
                pv.push(score, move, line);
            }
            
            alpha = std::max(alpha, score);
            if (config.alphaBetaPrunning && beta <= alpha) {
                break; // Beta cut-off
            }
        }
        return bestValue;
    }
    
    // https://chessprogramming.wikispaces.com/Quiescence+Search
    int quiescence(TNode node, int depth, int alpha, int beta, int color, Variation &pv, Variation &cv) {
        pv.qsDepth = depth;
        
        auto stand_pat = TNodeEvaluater::evaluate(node) * color;
        if (stand_pat >= beta) {
            return beta;
        }
        
        if (alpha < stand_pat) {
            alpha = stand_pat;
        }
        
        auto moves = TMoveGenerator::generateMoves(node, true);
        if (moves.count == 0) {
            return alpha;
        }
        
        if (config.sortMoves) {
            TMoveGenerator::sortMoves(moves);
        }
        
        for (int index=0; index<moves.count && analyzing; index++) {
            auto move = moves.moves[index];
            
            visitedNodes++;

            cv.moves.push(move);
            
            auto newNode = node;
            newNode.move(move);
            
            Variation line;
            int score = -quiescence(newNode, depth+1, -beta, -alpha, -color, line, cv);
            
            cv.moves.pop();

            pv.push(score, move, line);

            if (score >= beta) {
                return beta;
            }
            
            if (score > alpha) {
                alpha = score;
            }
        }
                
        return alpha;
    }
    
};
