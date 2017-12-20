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

template <class Node, class Evaluater>
class AlphaBeta {
    Evaluater evaluater;
    int maxDepth = 0;
    
public:
    int visitedNodes = 0;
    bool alphaBetaCutoff = true;
    bool debugOutput = false;
    
    AlphaBeta(Evaluater evaluater, int maxDepth) : evaluater(evaluater), maxDepth(maxDepth) { }

    void reset() {
        visitedNodes = 0;
    }
    
    void outputDebug(Node node, int depth, int alpha, int beta, bool maximizingPlayer) {
        if (debugOutput) {
            std::cout << "    Quiet node: " << node.description() << ", d=" << depth << ", a=" << alpha << ", b=" << beta << ", m=" << maximizingPlayer << std::endl;
        }
    }
    
    void outputCutoff(Node node, int depth, int alpha, int beta, bool maximizingPlayer) {
        if (debugOutput) {
            std::cout << "Cut-off (b<=a): " << node.description() << ", d=" << depth << ", a=" << alpha << ", b=" << beta << ", m=" << maximizingPlayer << std::endl;
        }
    }

    int alphabeta(Node node, int depth, int alpha, int beta, bool maximizingPlayer) {
        visitedNodes++;
        
        if (depth == maxDepth) {
            if (node.isQuiet()) {
                int value = evaluater.evaluate(node);
                outputDebug(node, depth, alpha, beta, maximizingPlayer);
                return value;
            } else {
                return quiescence(node, depth, alpha, beta, maximizingPlayer);
            }
        }
        
        auto children = node.children();
        std::stable_sort(children.begin(), children.end());

        if (maximizingPlayer) {
            int v = INT_MIN;
            for (Node child : children) {
                v = std::max(v, alphabeta(child, depth + 1, alpha, beta, false));
                alpha = std::max(alpha, v);
                if (alphaBetaCutoff && beta <= alpha) {
                    outputCutoff(child, depth, alpha, beta, maximizingPlayer);
                    break; // Beta cut-off
                }
            }
            return v;
        } else {
            int v = INT_MAX;
            for (Node child : children) {
                v = std::min(v, alphabeta(child, depth + 1, alpha, beta, true));
                beta = std::min(beta, v);
                if (alphaBetaCutoff && beta <= alpha) {
                    outputCutoff(child, depth, alpha, beta, maximizingPlayer);
                    break; // Alpha cut-off
                }
            }
            return v;
        }
    }
    
    int quiescence(Node node, int depth, int alpha, int beta, bool maximizingPlayer) {
        visitedNodes++;
        
        if (node.isQuiet()) {
            int value = evaluater.evaluate(node);
            outputDebug(node, depth, alpha, beta, maximizingPlayer);
            return value;
        }
        
        auto children = node.children();
        if (children.empty()) {
            // Terminal node
            int value = evaluater.evaluate(node);
            outputDebug(node, depth, alpha, beta, maximizingPlayer);
            return value;
        }
        
        if (maximizingPlayer) {
            int v = INT_MIN;
            for (Node child : children) {
                v = std::max(v, quiescence(child, depth + 1, alpha, beta, false));
                alpha = std::max(alpha, v);
                if (alphaBetaCutoff && beta <= alpha) {
                    outputCutoff(child, depth, alpha, beta, maximizingPlayer);
                    break; // Beta cut-off
                }
            }
            return v;
        } else {
            int v = INT_MAX;
            for (Node child : children) {
                v = std::min(v, quiescence(child, depth + 1, alpha, beta, true));
                beta = std::min(beta, v);
                if (alphaBetaCutoff && beta <= alpha) {
                    outputCutoff(child, depth, alpha, beta, maximizingPlayer);
                    break; // Alpha cut-off
                }
            }
            return v;
        }
    }

};
