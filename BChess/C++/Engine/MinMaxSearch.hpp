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
    int maxDepth = 0;
    bool debugLog = false;
    bool alphaBetaPrunning = true;
    bool quiescenceSearch = true;
};

template <class Node, class MoveGenerator, class Evaluater, class Evaluation>
class MinMaxSearch {
    Evaluater evaluater;
    MoveGenerator moveGenerator;
    
public:
    Configuration config;

    int visitedNodes = 0;
    
    MinMaxSearch(Evaluater evaluater, MoveGenerator moveGenerator) : evaluater(evaluater), moveGenerator(moveGenerator) { }
    MinMaxSearch(Evaluater evaluater, MoveGenerator moveGenerator, Configuration config) : evaluater(evaluater), moveGenerator(moveGenerator), config(config) { }

    void reset() {
        visitedNodes = 0;
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

    Evaluation alphabeta(Node node, int depth, int alpha, int beta, bool maximizingPlayer) {
        return alphabeta(node, depth, alpha, beta, maximizingPlayer, false);
    }
    
    Evaluation alphabeta(Node node, int depth, int alpha, int beta, bool maximizingPlayer, bool quiescence) {
        visitedNodes++;
        
        Evaluation bestEval;
        
        outputEnter(node, depth, alpha, beta, maximizingPlayer);

        if (quiescence) {
            auto stand_pat = evaluater.evaluate(node);
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
                    bestEval.value = evaluater.evaluate(node);
                    outputDebug(node, depth, alpha, beta, maximizingPlayer);
                    return bestEval;
                }
            }
        }
        
        auto moves = moveGenerator.generateMoves(node);

        std::stable_sort(std::begin(moves._moves), std::end(moves._moves));
        
        bool evaluatedAtLeastOneChild = false;
        
        bestEval.value = maximizingPlayer ? INT_MIN : INT_MAX;
        for (int index=0; index<moves.count; index++) {
            auto move = moves._moves[index];
            if (quiescence && evaluater.isQuiet(move)) {
                continue;
            }
            
            evaluatedAtLeastOneChild = true;
            
            auto newNode = node;
            newNode.move(move);
            auto candidate = alphabeta(newNode, depth + 1, alpha, beta, !maximizingPlayer, quiescence);
            if (maximizingPlayer) {
                if (candidate.value > bestEval.value) {
                    bestEval = candidate;
                    bestEval.addMove(move);
                    alpha = std::max(alpha, candidate.value);
                    outputBest(node, depth, alpha, beta, maximizingPlayer, bestEval);
                }
            } else {
                if (candidate.value < bestEval.value) {
                    bestEval = candidate;
                    bestEval.addMove(move);
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
            bestEval.value = evaluater.evaluate(node);
        }
        outputReturn(node, depth, alpha, beta, maximizingPlayer, bestEval);
        return bestEval;
    }
    
};
