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

struct Configuration {
    int maxDepth = 4;
    bool debugLog = false;
    bool alphaBetaPrunning = true;
    bool quiescenceSearch = true;
};

template <class Node, class MoveGenerator, class Evaluater, class Evaluation>
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

    void outputDebug(Node node, int depth, int alpha, int beta, bool maximizingPlayer) {
        if (config.debugLog) {
//            std::cout << "Quiet node: " << node.description() << ", d=" << depth << ", a=" << alpha << ", b=" << beta << ", m=" << maximizingPlayer << std::endl;
        }
    }

    void outputEnter(Node node, int depth, int alpha, int beta, bool maximizingPlayer) {
        if (config.debugLog) {
//            std::cout << "Enter node: " << node.description() << ", d=" << depth << ", a=" << alpha << ", b=" << beta << ", m=" << maximizingPlayer << std::endl;
        }
    }

    void outputReturn(Node node, int depth, int alpha, int beta, bool maximizingPlayer, Evaluation bestEval) {
        if (config.debugLog) {
//            std::cout << "Return from: " << node.description() << ", d=" << depth << ", a=" << alpha << ", b=" << beta << ", m=" << maximizingPlayer << ", bv=" << bestEval.value << std::endl;
        }
    }
    
    void outputBest(Node node, int depth, int alpha, int beta, bool maximizingPlayer, Evaluation bestEval) {
        if (config.debugLog) {
//            std::cout << "Best match: " << node.description() << ", d=" << depth << ", a=" << alpha << ", b=" << beta << ", m=" << maximizingPlayer << ", bv=" << bestEval.value << std::endl;
        }
    }
    
    void outputCutoff(Node node, int depth, int alpha, int beta, bool maximizingPlayer) {
        if (config.debugLog) {
//            std::cout << "Cut-off (b<=a): " << node.description() << ", d=" << depth << ", a=" << alpha << ", b=" << beta << ", m=" << maximizingPlayer << std::endl;
        }
    }

    Evaluation alphabeta(Node node, int depth, bool maximizingPlayer) {
        analyzing = true;
        return alphabeta(node, depth, INT_MIN, INT_MAX, maximizingPlayer, false);
    }

private:
        
    Evaluation alphabeta(Node node, int depth, int alpha, int beta, bool maximizingPlayer, bool quiescence) {
        visitedNodes++;
        
        Evaluation bestEval;
        bestEval.depth = depth;
        bestEval.nodes = visitedNodes;
        
        outputEnter(node, depth, alpha, beta, maximizingPlayer);

        if (quiescence) {
            auto stand_pat = Evaluater::evaluate(node);
            if (maximizingPlayer) {
                if (stand_pat > alpha) {
                    alpha = stand_pat;
                    if (config.alphaBetaPrunning && beta <= alpha) {
                        outputCutoff(node, depth, alpha, beta, maximizingPlayer);
                        bestEval.value = stand_pat;
                        return bestEval;
                    }
                }
            } else {
                if (stand_pat < beta) {
                    beta = stand_pat;
                    if (config.alphaBetaPrunning && beta <= alpha) {
                        outputCutoff(node, depth, alpha, beta, maximizingPlayer);
                        bestEval.value = stand_pat;
                        return bestEval;
                    }
                }
            }
        } else {
            if (depth == config.maxDepth) {
                if (config.quiescenceSearch) {
                    quiescence = true;
                } else {
                    bestEval.value = Evaluater::evaluate(node);
                    outputDebug(node, depth, alpha, beta, maximizingPlayer);
                    return bestEval;
                }
            }
        }
        
        auto moves = MoveGenerator::generateMoves(node);

        bool evaluatedAtLeastOneChild = false;
        
        bestEval.value = maximizingPlayer ? INT_MIN : INT_MAX;
        for (int index=0; index<moves.count; index++) {
            auto move = moves._moves[index];
            if (quiescence && Evaluater::isQuiet(move)) {
                continue;
            }
            
            if (!analyzing) {
                break;
            }
            
            evaluatedAtLeastOneChild = true;
            
            auto newNode = node;
            newNode.move(move);
            auto candidate = alphabeta(newNode, depth + 1, alpha, beta, !maximizingPlayer, quiescence);
            if (maximizingPlayer) {
                if (candidate.value > bestEval.value) {
                    bestEval = candidate;
                    bestEval.insertMove(depth, move);
                    alpha = std::max(alpha, candidate.value);
                    outputBest(node, depth, alpha, beta, maximizingPlayer, bestEval);
                }
            } else {
                if (candidate.value < bestEval.value) {
                    bestEval = candidate;
                    bestEval.insertMove(depth, move);
                    beta = std::min(beta, candidate.value);
                    outputBest(node, depth, alpha, beta, maximizingPlayer, bestEval);
                }
            }
            if (config.alphaBetaPrunning && beta <= alpha) {
                outputCutoff(newNode, depth, alpha, beta, maximizingPlayer);
                break; // Beta cut-off
            }
        }
        if (!evaluatedAtLeastOneChild) {
            bestEval.value = Evaluater::evaluate(node, moves);
        }
        outputReturn(node, depth, alpha, beta, maximizingPlayer, bestEval);
        return bestEval;
    }
    
};
