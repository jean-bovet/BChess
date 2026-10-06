//
//  FAlphaBeta.hpp
//  BChess
//
//  Created by Jean Bovet on 12/18/17.
//  Copyright © 2017 Jean Bovet. All rights reserved.
//

#pragma once

#include <stdio.h>
#include <atomic>
#include <climits>
#include <algorithm>
#include <functional>
#include <iostream>

#include "MoveList.hpp"
#include "TranspositionTable.hpp"

#include "MoveList.hpp"
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
    MoveList moves;
    
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
    // Set from any thread to end the running search. It is cleared only by resume(), never by a search
    // itself, so a cancel can never be lost between two depths.
    std::atomic<bool> stopRequested{false};
    
public:
    Configuration config;
    
    int64_t visitedNodes = 0;
    
    // The deepest ply visited by alphabeta or quiescence since reset()
    int64_t maxPly = 0;
    
#ifdef BCHESS_TEST_HOOKS
    // Called in the move loop right after the move has been pushed on the history. Tests use it to
    // stop the search at an exact node, or to park the search thread inside alpha-beta.
    std::function<void()> checkpoint;
#endif
    
    void reset() {
        visitedNodes = 0;
        maxPly = 0;
    }

    void cancel() {
        stopRequested.store(true, std::memory_order_relaxed);
    }
    
    // Allows a new search to run after cancel().
    void resume() {
        stopRequested.store(false, std::memory_order_relaxed);
    }
    
    bool stopped() const {
        return stopRequested.load(std::memory_order_relaxed);
    }
    
    typedef MinMaxVariation Variation;
    
    // pv: Principal Variation that will be available when this method returns.
    // bv: Best Variation that is provided from an earlier search (typically by the iterative deepening algorithm).
    int alphabeta(ChessBoard node, HistoryPtr history, TranspositionTable &table, int depth, bool maximizingPlayer, Variation &pv, Variation &bv) {
        Variation currentLine;
        int color = maximizingPlayer ? 1 : -1;
        int score = alphabeta(node, history, table, depth, -INT_MAX, INT_MAX, color, pv, currentLine, bv);
        return score * color;
    }
    
    // Whether a table entry settles the node at `ply`, and then its value. The entry holds mates relative to its
    // own node, so the value is turned relative to the root before it is compared with alpha and beta.
    static bool ttCutoff(const TranspositionEntry &entry, int ply, int alpha, int beta, int &value) {
        value = ttValueFromProbe(entry.value, ply);
        switch (entry.type) {
            case TranspositionEntryType::EXACT:
                return true;
            case TranspositionEntryType::ALPHA:
                return value <= alpha;
            case TranspositionEntryType::BETA:
                return value >= beta;
        }
        return false;
    }
    
private:
    
    // A mate found at this ply from the root is worth less than a mate found closer to it
    static int mateAtPly(int score, int ply) {
        if (score == ChessEvaluater::MAT_VALUE) {
            return score - ply;
        } else if (score == -ChessEvaluater::MAT_VALUE) {
            return score + ply;
        }
        return score;
    }
    
    // The table holds a mate relative to its own node, so that another path to the node reads it right
    static int ttValueToStore(int value, int ply) {
        if (!ChessEvaluater::isMateScore(value)) {
            return value;
        }
        return value > 0 ? value + ply : value - ply;
    }
    
    static int ttValueFromProbe(int value, int ply) {
        if (!ChessEvaluater::isMateScore(value)) {
            return value;
        }
        return value > 0 ? value - ply : value + ply;
    }
    
    // pv: Principal Variation - the best line found so far.
    // cv: Current Variation - the current line being examined.
    // bv: Best Variation - if available
    // https://en.wikipedia.org/wiki/Negamax
    // https://chessprogramming.wikispaces.com/Principal+variation
    int alphabeta(ChessBoard node, HistoryPtr history, TranspositionTable &table, int depth, int alpha, int beta, int color, Variation &pv, Variation &cv, Variation &bv) {
        pv.depth = depth;
        maxPly = std::max<int64_t>(maxPly, depth);

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
            int value = 0;
            if (entry.depth >= evalDepth && ttCutoff(entry, depth, alpha, beta, value)) {
                assert(ChessMoveGenerator::isValid(entry.bestMove));
                pv.push(value, entry.bestMove, Variation());
                return value;
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
                int score = mateAtPly(ChessEvaluater::evaluate(node, history) * color, depth);
                return score;
            }
        }
        
        auto moves = ChessMoveGenerator::generateMoves(node);
        if (moves.count == 0) {
            int score = mateAtPly(ChessEvaluater::evaluate(node, history, moves) * color, depth);
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
        for (int index=-1; index<moves.count && !stopped(); index++) {
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
#ifdef BCHESS_TEST_HOOKS
            if (checkpoint) checkpoint();
#endif
            
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

        // The store does not look at config.transpositionTable, which gates only the cut-offs above: the table
        // also orders the moves of a later search, whatever the setting.
        // A loop that was cut short holds a partial value, which must not be trusted by a later search
        // of the same position. Its parents are cut short too, so they store nothing either.
        if (ChessMoveGenerator::isValid(bestMove) && !stopped()) {
            table.store(evalDepth, node.getHash(), ttValueToStore(bestValue, depth), bestMove, entryType
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
        maxPly = std::max<int64_t>(maxPly, depth);
        
        if (ChessEvaluater::isDraw(node, history)) {
            return 0;
        }

        auto stand_pat = mateAtPly(ChessEvaluater::evaluate(node, history) * color, depth);
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
        
        // Fail-soft like alphabeta: the best score so far, never below the stand-pat
        int bestValue = stand_pat;
        for (int index=0; index<moves.count && !stopped(); index++) {
            auto move = moves.moves[index];
            
            visitedNodes++;
            
            auto newNode = node;
            newNode.move(move);

            cv.moves.push(move);
            history->push_back(newNode.getHash());

            Variation line;
            int score = -quiescence(newNode, history, depth+1, -beta, -alpha, -color, line, cv);
            
            cv.moves.pop();
            history->pop_back();

            if (score > bestValue) {
                bestValue = score;
            }
            
            if (score >= alpha) {
                alpha = score;
                pv.push(score, move, line);
                
                if (score >= beta) break;
            }
        }
                
        return bestValue;
    }
    
};
