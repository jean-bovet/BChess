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
#include "TranspositionTable.hpp"

#include "ChessMoveList.hpp"
#include "ChessEvaluater.hpp"
#include "ChessMoveGenerator.hpp"

#ifdef ASSERT_TT_KEY_COLLISION
#include "FFEN.hpp"
#endif

struct Configuration {
    int maxDepth = 4;
    bool debugLog = false;
    bool alphaBetaPrunning = true;
    bool quiescenceSearch = true;
    bool sortMoves = true;
    bool transpositionTable = true;
};

struct MinMaxVariation {
    ChessMoveList moves;
    
    int depth = 0;
    int qsDepth = 0;
    
    int value = 0;

    void push(int score, Move move, MinMaxVariation line) {
        value = score;
        
        depth = std::max(depth, line.depth);
        qsDepth = line.qsDepth;
        
        moves.count = 0;
        moves.push(move);
        moves.push(line.moves);
    }

};

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
    
    typedef MinMaxVariation Variation;
    
    // pv: Principal Variation that will be available when this method returns.
    // bv: Best Variation that is provided from an earlier search (typically by the iterative deepening algorithm).
    int alphabeta(ChessBoard node, HistoryPtr history, TranspositionTable &table, int depth, bool maximizingPlayer, Variation &pv, Variation &bv) {
        analyzing = true;
        Variation currentLine;
        int color = maximizingPlayer ? 1 : -1;
        int score = alphabeta(node, history, table, depth, -INT_MAX, INT_MAX, color, pv, currentLine, bv);
        return score * color;
    }
    
private:
    
    // pv: Principal Variation - the best line found so far.
    // cv: Current Variation - the current line being examined.
    // bv: Best Variation - if available
    // https://en.wikipedia.org/wiki/Negamax
    // https://chessprogramming.wikispaces.com/Principal+variation
    int alphabeta(ChessBoard node, HistoryPtr history, TranspositionTable &table, int depth, int alpha, int beta, int color, Variation &pv, Variation &cv, Variation &bv) {
        pv.depth = depth;

        int evalDepth = config.maxDepth - depth;
        
        // Check if we have the same node already in our transposition table.
        if (config.transpositionTable &&
            table.exists(node.getHash()
#ifdef ASSERT_TT_KEY_COLLISION
                         , FFEN::getFEN(node, true)
#endif
                         )) {
            auto entry = table.get(node.getHash());
            
            // Make sure the entry exists and that its depth is at least what we are at right now
            if (entry.depth >= evalDepth) {
                switch (entry.type) {
                    case TranspositionEntryType::EXACT:
                        // Exact value: use it right away
                        assert(ChessMoveGenerator::isValid(entry.bestMove));
                        pv.push(entry.value, entry.bestMove, Variation());
                        return entry.value;
                        
                    case TranspositionEntryType::ALPHA:
                        if (entry.value <= alpha) {
                            assert(ChessMoveGenerator::isValid(entry.bestMove));
                            pv.push(entry.value, entry.bestMove, Variation());
                            return entry.value;
                        }
                        break;
                        
                    case TranspositionEntryType::BETA:
                        if (entry.value >= beta) {
                            assert(ChessMoveGenerator::isValid(entry.bestMove));
                            pv.push(entry.value, entry.bestMove, Variation());
                            return entry.value;
                        }
                        break;
                }
            }
        }

        if (ChessEvaluater::isDraw(node, history)) {
            return 0;
        }

        if (depth == config.maxDepth) {
            if (config.quiescenceSearch) {
                int score = quiescence(node, history, depth, alpha, beta, color, pv, cv);
                return score;
            } else {
                int score = ChessEvaluater::evaluate(node, history) * color;
                return score;
            }
        }
        
        auto moves = ChessMoveGenerator::generateMoves(node);
        if (moves.count == 0) {
            int score = ChessEvaluater::evaluate(node, history, moves) * color;
            return score;
        }
        
        if (config.sortMoves) {
            ChessMoveGenerator::sortMoves(moves);
        }
        
        // Lookup the best move if available in the best variation
        auto bestMovePV = bv.moves.lookup(depth);

        int bestValue = -INT_MAX;
        TranspositionEntryType entryType = TranspositionEntryType::ALPHA;
        
        Move bestMove = INVALID_MOVE;
        for (int index=-1; index<moves.count && analyzing; index++) {
            Move move = Move();
            if (index == -1) {
                // At index -1 we try to evaluate the previously detected
                // best move, if available.
                if (ChessMoveGenerator::isValid(bestMovePV)) {
                    // Analyze the best move first
                    move = bestMovePV;
                } else {
                    // Let's skip this best move and start with the generated moves
                    continue;
                }
            } else {
                // Above index -1, we analyze the generated moves
                move = moves.moves[index];
                
                // Skip this move if it is the best move (which has been analyzed first)
                if (move == bestMovePV) {
                    continue;
                }
            }
            
            visitedNodes++;

            auto newNode = node;
            newNode.move(move);
            
            cv.moves.push(move);
            history->push_back(newNode.getHash());
            
            Variation line;
            Variation bestLine = (move == bestMovePV) ? bv : Variation();
            int score = -alphabeta(newNode, history, table, depth + 1, -beta, -alpha, -color, line, cv, bestLine);
            
            cv.moves.pop();
            history->pop_back();
            
            if (score > bestValue) {
                bestValue = score;
                bestMove = move;
                
                pv.push(score, move, line);
                
                if (score > alpha) {
                    alpha = score;
                    entryType = TranspositionEntryType::EXACT;
                }
                
                if (config.alphaBetaPrunning && beta <= alpha) {
                    entryType = TranspositionEntryType::BETA;
                    break; // Beta cut-off
                }
            }
        }

        if (ChessMoveGenerator::isValid(bestMove)) {
            table.store(evalDepth, node.getHash(), bestValue, bestMove, entryType
#ifdef ASSERT_TT_KEY_COLLISION
                        , FFEN::getFEN(node, true)
#endif
                        );
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
    int quiescence(ChessBoard node, HistoryPtr history, int depth, int alpha, int beta, int color, Variation &pv, Variation &cv) {
        pv.qsDepth = depth;
        
        if (ChessEvaluater::isDraw(node, history)) {
            return 0;
        }

        auto stand_pat = ChessEvaluater::evaluate(node, history) * color;
        if (stand_pat >= beta) {
            return stand_pat;
        }
        
        if (alpha < stand_pat) {
            alpha = stand_pat;
        }

        auto moves = ChessMoveGenerator::generateQuiescenceMoves(node);
        if (moves.count == 0) {
            return stand_pat;
        }
        
        if (config.sortMoves) {
            ChessMoveGenerator::sortMoves(moves);
        }
        
        int score = stand_pat;
        for (int index=0; index<moves.count && analyzing; index++) {
            auto move = moves.moves[index];
            
            visitedNodes++;
            
            auto newNode = node;
            newNode.move(move);

            cv.moves.push(move);
            history->push_back(newNode.getHash());

            Variation line;
            score = -quiescence(newNode, history, depth+1, -beta, -alpha, -color, line, cv);
            
            cv.moves.pop();
            history->pop_back();

            if (score >= alpha) {
                alpha = score;
                pv.push(score, move, line);
                
                if (score >= beta) break;
            }
        }
                
        return score;
    }
    
};
