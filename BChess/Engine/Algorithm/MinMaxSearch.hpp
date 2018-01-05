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

//#include "FPGN.hpp"

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
    
    // pv: Principal Variation that will be available when this method returns.
    // bv: Best Variation that is provided from an earlier search (typically by the iterative deepening algorithm).
    int alphabeta(TNode node, int depth, bool maximizingPlayer, Variation &pv, Variation &bv) {
        analyzing = true;
        Variation currentLine;
        int color = maximizingPlayer ? 1 : -1;
        int score = alphabeta(node, depth, -INT_MAX, INT_MAX, color, pv, currentLine, bv);
        return score * color;
    }
    
private:
    
    // pv: Principal Variation - the best line found so far.
    // cv: Current Variation - the current line being examined.
    // bv: Best Variation - if available
    // https://en.wikipedia.org/wiki/Negamax
    // https://chessprogramming.wikispaces.com/Principal+variation
    int alphabeta(TNode node, int depth, int alpha, int beta, int color, Variation &pv, Variation &cv, Variation &bv) {
        pv.depth = depth;

        if (depth == config.maxDepth) {
            if (config.quiescenceSearch) {
                bool debug = false;
//                bool debug = cv.moves.description() == "Bf8b4 c2c3 Qd8e7 Ng1e2";
//                bool debug = cv.moves.description() == "Bf8b4 c2c3 a7a6 c3xb4";
//                bool debug = cv.moves.description() == "Qf5xf6";
//                if (debug) {
//                    std::cout << "Before quiescence at depth " << depth << " cv=" << cv.moves.description() << " alpha=" << alpha << ", beta=" << beta << std::endl;
//                }
                int score = quiescence(node, depth, alpha, beta, color, pv, cv, debug);
//                if (debug) {
//                    std::cout << "After quiescence at depth " << depth << " cv=" << cv.moves.description() << " pv=" << pv.moves.description() << " score=" << score << std::endl;
//                }
                return score;
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
        
        // Lookup the best move if available in the best variation
        auto bestMove = bv.moves.lookup(depth);

        int bestValue = -INT_MAX;
        for (int index=-1; index<moves.count && analyzing; index++) {
            TMove move = TMove();
            if (index == -1) {
                // At index -1 we try to evaluate the previously detected
                // best move, if available.
                if (TMoveGenerator::isValid(bestMove)) {
                    // Analyze the best move first
                    move = bestMove;
                } else {
                    // Let's skip this best move and start with the generated moves
                    continue;
                }
            } else {
                // Above index -1, we analyze the generated moves
                move = moves.moves[index];
                
                // Skip this move if it is the best move (which has been analyzed first)
                if (move == bestMove) {
                    continue;
                }
            }
            
            visitedNodes++;

            cv.moves.push(move);

            auto newNode = node;
            newNode.move(move);
            
            Variation line;
            Variation bestLine = (move == bestMove) ? bv : Variation();
            int score = -alphabeta(newNode, depth + 1, -beta, -alpha, -color, line, cv, bestLine);
            
            cv.moves.pop();
            
//            if (depth == 0) {
//                std::cout << "* " << FPGN::to_string(move, FPGN::SANType::full) << " " << line.moves.description() << ", score = " << score << ", alpha = " << alpha << ", beta = " << beta << std::endl;
//            }
            
            if (score > bestValue) {
                bestValue = score;
            
                pv.push(score, move, line);
//                if (depth == 0) {
//                    std::cout << "Bestline: " << pv.moves.description() << std::endl;
//                }
            }
            
            alpha = std::max(alpha, score);
            if (config.alphaBetaPrunning && beta <= alpha) {
                break; // Beta cut-off
            }
        }
        return bestValue;
    }
    
    // https://chessprogramming.wikispaces.com/Quiescence+Search
    // Note: the search described in the link above returns alpha which doesn't work
    // with the positions I've been analyzing (returning alpha will never return the
    // position evaluation but rather the previous alpha and this won't work). However
    // this link shows quiescence search that returns the score, like regular negamax
    // and this is way better IMO:
    // https://www.ics.uci.edu/~eppstein/180a/990204.html
    int quiescence(TNode node, int depth, int alpha, int beta, int color, Variation &pv, Variation &cv, bool debug) {
        pv.qsDepth = depth;
        
        auto stand_pat = TNodeEvaluater::evaluate(node) * color;
//        if (debug) {
//            std::cout << "[q] " << depth << ": " << cv.moves.description() << ", alpha=" << alpha << ", beta=" << beta << " color = " << color << std::endl;
//            std::cout << "[q] " << depth << ": " << "stand_pat = " << stand_pat << std::endl;
//        }
        
        if (stand_pat >= beta) {
//            if (debug) {
//                std::cout << "[q] " << depth << ": " << "stand_pat >= beta (" << stand_pat << " >= " << beta << ") => return stand_pat" << std::endl;
//            }
            return stand_pat;
        }
        
        if (alpha < stand_pat) {
//            if (debug) {
//                std::cout << "[q] " << depth << ": " << "stand_pat > alpha (" << stand_pat << " > " << alpha << ") => alpha = " << stand_pat << std::endl;
//            }
            alpha = stand_pat;
        }

        auto moves = TMoveGenerator::generateQuiescenceMoves(node);
        if (moves.count == 0) {
//            if (debug) {
//                std::cout << "[q] " << depth << ": " << "moves.count == 0, return stand_pat " << stand_pat << std::endl;
//            }
            return stand_pat;
        }
        
        if (config.sortMoves) {
            TMoveGenerator::sortMoves(moves);
        }
        
        int score = stand_pat;
        for (int index=0; index<moves.count && analyzing; index++) {
            auto move = moves.moves[index];
            
            visitedNodes++;

            cv.moves.push(move);
            
            auto newNode = node;
            newNode.move(move);
            
            Variation line;
            score = -quiescence(newNode, depth+1, -beta, -alpha, -color, line, cv, debug);
            
            cv.moves.pop();

            if (score >= alpha) {
//                if (debug) {
//                    std::cout << "[q] " << depth << ": " << "score >= alpha (" << score << " > " << alpha << ") => alpha = " << score << std::endl;
//                }
                
                alpha = score;
                pv.push(score, move, line);
                
                if (score >= beta) break;
            }
        }
        
//        if (debug) {
//            std::cout << "[q] " << depth << ": " << "return score = " << score << std::endl;
//        }
        
        return score;
    }
    
};
