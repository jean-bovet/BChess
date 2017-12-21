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

struct Configuration {
    int maxDepth = 0;
    bool debugLog = false;
    bool alphaBetaPrunning = true;
    bool quiescenceSearch = true;
};

template <class Node, class Evaluater, class Evaluation>
class AlphaBeta {
    Evaluater evaluater;
    
public:
    Configuration config;

    int visitedNodes = 0;
    
    AlphaBeta(Evaluater evaluater) : evaluater(evaluater) { }
    AlphaBeta(Evaluater evaluater, Configuration config) : evaluater(evaluater), config(config) { }

    void reset() {
        visitedNodes = 0;
    }
    
    void outputDebug(Node node, int depth, int alpha, int beta, bool maximizingPlayer) {
        if (config.debugLog) {
            std::cout << "Quiet node: " << node.description() << ", d=" << depth << ", a=" << alpha << ", b=" << beta << ", m=" << maximizingPlayer << std::endl;
        }
    }

    void outputEnter(Node node, int depth, int alpha, int beta, bool maximizingPlayer) {
        if (config.debugLog) {
            std::cout << "Enter node: " << node.description() << ", d=" << depth << ", a=" << alpha << ", b=" << beta << ", m=" << maximizingPlayer << std::endl;
        }
    }

    void outputReturn(Node node, int depth, int alpha, int beta, bool maximizingPlayer, Evaluation bestEval) {
        if (config.debugLog) {
            std::cout << "Return from: " << node.description() << ", d=" << depth << ", a=" << alpha << ", b=" << beta << ", m=" << maximizingPlayer << ", bv=" << bestEval.value << std::endl;
        }
    }
    
    void outputBest(Node node, int depth, int alpha, int beta, bool maximizingPlayer, Evaluation bestEval) {
        if (config.debugLog) {
            std::cout << "Best match: " << node.description() << ", d=" << depth << ", a=" << alpha << ", b=" << beta << ", m=" << maximizingPlayer << ", bv=" << bestEval.value << std::endl;
        }
    }
    
    void outputCutoff(Node node, int depth, int alpha, int beta, bool maximizingPlayer) {
        if (config.debugLog) {
            std::cout << "Cut-off (b<=a): " << node.description() << ", d=" << depth << ", a=" << alpha << ", b=" << beta << ", m=" << maximizingPlayer << std::endl;
        }
    }

    Evaluation alphabeta(Node node, int depth, int alpha, int beta, bool maximizingPlayer) {
        return alphabeta(node, depth, alpha, beta, maximizingPlayer, false);
    }
    
    Evaluation alphabeta(Node node, int depth, int alpha, int beta, bool maximizingPlayer, bool quiescence) {
        visitedNodes++;
        
        outputEnter(node, depth, alpha, beta, maximizingPlayer);

        std::vector<Node> children = node.children();
        if (quiescence) {
            Evaluation stand_pat = evaluater.evaluate(node);
            if (maximizingPlayer) {
                if (stand_pat.value > alpha) {
                    alpha = stand_pat.value;
                    if (config.alphaBetaPrunning && beta <= alpha) {
                        outputCutoff(node, depth, alpha, beta, maximizingPlayer);
                        return stand_pat;
                    }
                }
            } else {
                if (stand_pat.value < beta) {
                    beta = stand_pat.value;
                    if (config.alphaBetaPrunning && beta <= alpha) {
                        outputCutoff(node, depth, alpha, beta, maximizingPlayer);
                        return stand_pat;
                    }
                }
            }
        } else {
            if (depth == config.maxDepth) {
                if (config.quiescenceSearch) {
                    quiescence = true;
                } else {
                    Evaluation eval = evaluater.evaluate(node);
                    outputDebug(node, depth, alpha, beta, maximizingPlayer);
                    return eval;
                }
            }
        }

        std::stable_sort(children.begin(), children.end());

        bool evaluatedAtLeastOneChild = false;
        
        if (maximizingPlayer) {
            Evaluation bestEval;
            bestEval.value = INT_MIN;
            for (Node child : children) {
                if (quiescence && child.isQuiet()) {
                    continue;
                }
                evaluatedAtLeastOneChild = true;
                auto candidate = alphabeta(child, depth + 1, alpha, beta, false, quiescence);
                if (candidate.value > bestEval.value) {
                    bestEval = candidate;
                    alpha = std::max(alpha, candidate.value);
                    outputBest(node, depth, alpha, beta, maximizingPlayer, bestEval);
                }
                if (config.alphaBetaPrunning && beta <= alpha) {
                    outputCutoff(child, depth, alpha, beta, maximizingPlayer);
                    break; // Beta cut-off
                }
            }
            if (!evaluatedAtLeastOneChild) {
                Evaluation eval = evaluater.evaluate(node);
                outputDebug(node, depth, alpha, beta, maximizingPlayer);
                return eval;
            }
            outputReturn(node, depth, alpha, beta, maximizingPlayer, bestEval);
            return bestEval;
        } else {
            Evaluation bestEval;
            bestEval.value = INT_MAX;
            for (Node child : children) {
                if (quiescence && child.isQuiet()) {
                    continue;
                }
                evaluatedAtLeastOneChild = true;
                auto candidate = alphabeta(child, depth + 1, alpha, beta, true, quiescence);
                if (candidate.value < bestEval.value) {
                    bestEval = candidate;
                    beta = std::min(beta, candidate.value);
                    outputBest(node, depth, alpha, beta, maximizingPlayer, bestEval);
                }
                if (config.alphaBetaPrunning && beta <= alpha) {
                    outputCutoff(child, depth, alpha, beta, maximizingPlayer);
                    break; // Alpha cut-off
                }
            }
            if (!evaluatedAtLeastOneChild) {
                Evaluation eval = evaluater.evaluate(node);
                outputDebug(node, depth, alpha, beta, maximizingPlayer);
                return eval;
            }
            outputReturn(node, depth, alpha, beta, maximizingPlayer, bestEval);
            return bestEval;
        }
    }
    
};
