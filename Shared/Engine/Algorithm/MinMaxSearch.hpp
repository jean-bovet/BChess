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
    
    // Quiescence skips a capture that cannot lift the score to alpha even with a margin, unless it gives check
    bool deltaPruning = true;
};

struct MinMaxVariation {
    MoveList moves;
    
    int depth = 0;
    int qsDepth = 0;
    
    int value = 0;

    void push(int score, Move move, const MinMaxVariation &line) {
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
    // Quiescence from the position as the search calls it at the horizon, with a window chosen by the test
    // and, when it matters, the ply it starts at
    int quiescenceForTest(ChessBoard node, int alpha, int beta, int color, MinMaxVariation &pv, int ply = 0) {
        Variation cv;
        return quiescence(node, ply, alpha, beta, color, pv, cv);
    }
    
    // Called in the move loop right after the move has been pushed on the history. Tests use it to
    // stop the search at an exact node, or to park the search thread inside alpha-beta.
    std::function<void()> checkpoint;
#endif
    
    void reset() {
        visitedNodes = 0;
        maxPly = 0;
    }
    
    // The two quiet moves that most recently cut a node off at each ply, newest first. A ply past MAX_PLY has
    // none. Iterative deepening clears them at the start of a search and keeps them across its depths.
    static const int MAX_PLY = 128;
    Move killers[MAX_PLY][2] = {};
    
    void clearKillers() {
        for (auto &ply : killers) {
            ply[0] = ply[1] = INVALID_MOVE;
        }
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
    
    // The line that a move off the best variation is searched with. Read only, so it is built once.
    inline static const Variation emptyLine = Variation();
    
    // pv: Principal Variation that will be available when this method returns.
    // bv: Best Variation that is provided from an earlier search (typically by the iterative deepening algorithm).
    // ply: the ply the root is at, 0 in every caller but the tests that put it at the boundary of MAX_PLY. The
    // search itself goes config.maxDepth plies deep from the root, wherever it starts.
    int alphabeta(ChessBoard node, const HistoryPtr &history, TranspositionTable &table, int ply, bool maximizingPlayer, Variation &pv, const Variation &bv) {
        Variation currentLine;
        int color = maximizingPlayer ? 1 : -1;
        int score = alphabeta(node, history, table, ply, config.maxDepth, -INT_MAX, INT_MAX, color, pv, currentLine, bv);
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
    
    // A quiet move that cuts a node off becomes the first killer of its ply, the previous one the second
    void recordKiller(int ply, Move move) {
        if (ply >= MAX_PLY || MOVE_IS_CAPTURE(move) || MOVE_PROMOTION_PIECE(move) != 0 || killers[ply][0] == move) {
            return;
        }
        killers[ply][1] = killers[ply][0];
        killers[ply][0] = move;
    }
    
    // Puts the killers of the ply that the list has first among the quiet moves, behind the captures that the
    // sort put at the front. The order stays: captures, killer 0, killer 1, the other quiet moves.
    void promoteKillers(MoveList &moves, int ply) {
        int target = 0;
        while (target < moves.count && MOVE_IS_CAPTURE(moves.moves[target])) {
            target++;
        }
        for (Move killer : killers[ply]) {
            if (!ChessMoveGenerator::isValid(killer)) {
                continue;
            }
            for (int index=target; index<moves.count; index++) {
                if (moves.moves[index] == killer) {
                    std::rotate(moves.moves + target, moves.moves + index, moves.moves + index + 1);
                    target++;
                    break;
                }
            }
        }
    }
    
    // The best move that the table holds for the position, or an invalid move
    static Move tableMove(TranspositionTable &table, ChessBoard &node) {
        BoardHash hash = node.getHash();
        if (table.exists(hash
#ifdef ASSERT_TT_KEY_COLLISION
                         , FFEN::getFEN(node, true)
#endif
                         )) {
            return table.get(hash).bestMove;
        }
        return INVALID_MOVE;
    }
    
    // ply: plies from the root. depthLeft: plies still to search below this node, the horizon being 0.
    // pv: Principal Variation - the best line found so far.
    // cv: Current Variation - the current line being examined.
    // bv: Best Variation - if available
    // https://en.wikipedia.org/wiki/Negamax
    // https://chessprogramming.wikispaces.com/Principal+variation
    int alphabeta(ChessBoard node, const HistoryPtr &history, TranspositionTable &table, int ply, int depthLeft, int alpha, int beta, int color, Variation &pv, Variation &cv, const Variation &bv) {
        pv.depth = ply;
        maxPly = std::max<int64_t>(maxPly, ply);

        // The line cannot get any longer: the killers and the move list are sized for MAX_PLY
        if (ply >= MAX_PLY) {
            return mateAtPly(ChessEvaluater::evaluate(node) * color, ply);
        }
        
        int evalDepth = depthLeft;
        
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
            if (entry.depth >= evalDepth && ttCutoff(entry, ply, alpha, beta, value)) {
                assert(ChessMoveGenerator::isValid(entry.bestMove));
                pv.push(value, entry.bestMove, emptyLine);
                return value;
            }
        }

        // The only repetition check of the node: quiescence and evaluate trust it. A quiescence move is a capture,
        // and no position after a capture can repeat an earlier one.
        if (ChessEvaluater::isDraw(node, history)) {
            return 0;
        }

        if (depthLeft <= 0) {
            if (config.quiescenceSearch) {
                int score = quiescence(node, ply, alpha, beta, color, pv, cv);
                return score;
            } else {
                int score = mateAtPly(ChessEvaluater::evaluate(node) * color, ply);
                return score;
            }
        }
        
        auto moves = ChessMoveGenerator::generateMoves(node);
        if (moves.count == 0) {
            int score = mateAtPly(ChessEvaluater::evaluate(node, moves) * color, ply);
            return score;
        }
        
        if (config.sortMoves) {
            ChessMoveGenerator::sortMoves(moves);
            promoteKillers(moves, ply);
        }
        
        // The move to try first. The previous iteration's best variation comes first, whatever sortMoves says.
        // Without one, the table's best move for this position, which every search stores whether or not the
        // table cuts off. sortMoves = false leaves the table out. A move the position does not have (a collision
        // or an old entry) is not in the list and so is never played.
        auto bestMovePV = bv.moves.lookup(ply);
        Move firstMove = bestMovePV;
        if (!ChessMoveGenerator::isValid(firstMove) && config.sortMoves) {
            firstMove = tableMove(table, node);
        }
        if (ChessMoveGenerator::isValid(firstMove)) {
            for (int index=0; index<moves.count; index++) {
                if (moves.moves[index] == firstMove) {
                    std::rotate(moves.moves, moves.moves + index, moves.moves + index + 1);
                    break;
                }
            }
        }

        int bestValue = -INT_MAX;
        TranspositionEntryType entryType = TranspositionEntryType::ALPHA;
        
        Move bestMove = INVALID_MOVE;
        for (int index=0; index<moves.count && !stopped(); index++) {
            Move move = moves.moves[index];
            
            visitedNodes++;

            auto newNode = node;
            newNode.move(move);
            
            cv.moves.push(move);
            history->push_back(newNode.getHash());
#ifdef BCHESS_TEST_HOOKS
            if (checkpoint) checkpoint();
#endif
            
            Variation line;
            const Variation &bestLine = (move == bestMovePV) ? bv : emptyLine;
            int score = -alphabeta(newNode, history, table, ply + 1, depthLeft - 1, -beta, -alpha, -color, line, cv, bestLine);
            
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
                    if (config.sortMoves) {
                        recordKiller(ply, move);
                    }
                    break; // Beta cut-off
                }
            }
        }

        // The store does not look at config.transpositionTable, which gates only the cut-offs above: the table
        // also orders the moves of a later search, whatever the setting.
        // A loop that was cut short holds a partial value, which must not be trusted by a later search
        // of the same position. Its parents are cut short too, so they store nothing either.
        if (ChessMoveGenerator::isValid(bestMove) && !stopped()) {
            table.store(evalDepth, node.getHash(), ttValueToStore(bestValue, ply), bestMove, entryType
#ifdef ASSERT_TT_KEY_COLLISION
                        , FFEN::getFEN(node, true)
#endif
                        );
        }

        return bestValue;
    }
    
    // Delta pruning's margin in centipawns, for what a position is worth beyond the material it wins
    static const int DELTA_MARGIN = 200;
    
    // https://chessprogramming.wikispaces.com/Quiescence+Search
    // Note: the search described in the link above returns alpha which doesn't work
    // with the positions I've been analyzing (returning alpha will never return the
    // position evaluation but rather the previous alpha and this won't work). However
    // this link shows quiescence search that returns the score, like regular negamax
    // and this is way better IMO:
    // https://www.ics.uci.edu/~eppstein/180a/990204.html
    int quiescence(ChessBoard node, int depth, int alpha, int beta, int color, Variation &pv, Variation &cv) {
        pv.qsDepth = depth;
        maxPly = std::max<int64_t>(maxPly, depth);
        
        auto stand_pat = mateAtPly(ChessEvaluater::evaluate(node) * color, depth);
        
        // The line cannot get any longer, as in alphabeta
        if (depth >= MAX_PLY || stand_pat >= beta) {
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
            
            auto newNode = node;
            newNode.move(move);
            
            // Delta pruning: this capture cannot lift the score to alpha, even with a margin. Not a promotion,
            // not while alpha is a mate score, and never a capture that gives check, which may mate. One rule
            // for every pruning of the quiescence search.
            if (config.deltaPruning && MOVE_PROMOTION_PIECE(move) == 0 && !ChessEvaluater::isMateScore(alpha) &&
                stand_pat + ChessEvaluater::pieceValue(MOVE_CAPTURED_PIECE(move)) + DELTA_MARGIN <= alpha &&
                !newNode.isCheck(newNode.color)) {
                continue;
            }
            
            visitedNodes++;

            cv.moves.push(move);

            Variation line;
            int score = -quiescence(newNode, depth+1, -beta, -alpha, -color, line, cv);
            
            cv.moves.pop();

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
