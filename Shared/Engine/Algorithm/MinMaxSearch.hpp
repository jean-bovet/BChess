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
    
    // Principal variation search: after the first move, a move is first searched with a zero window around alpha
    // and searched again in full only when it beats alpha. Needs alphaBetaPrunning.
    bool principalVariationSearch = true;
    
    // Null-move pruning: a node that is far above beta even after passing the turn is cut off
    bool nullMove = true;
    
    // Late-move reductions: the late quiet moves of a node are searched shallower first. Needs principalVariationSearch.
    bool lateMoveReductions = true;
    
    // Futility pruning: one ply from the horizon, quiet moves are skipped in a node that is far below alpha
    bool futilityPruning = true;
    
    // Quiescence skips a capture that cannot lift the score to alpha even with a margin, unless it gives check
    bool deltaPruning = true;
    
    // Quiescence skips a capture that loses material in the exchange on its square (SEE below 0), unless it gives
    // check or promotes
    bool seePruning = true;
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
    
    // The 0s that a repetition or the fifty-move rule returned since reset(). Both belong to the path, not to the
    // position, so a node that saw one below it must not store its value for another path to read.
    // Insufficient material does not count: it is a property of the position.
    int64_t pathDraws = 0;
    
    // The reduced moves that beat alpha and were searched again at full depth since reset()
    int64_t reductionResearches = 0;
    
    // The searches repeated in full at a PV node because a zero-window or a later child beat alpha, since reset()
    int64_t pvResearches = 0;
    
    // The deepest ply that alphabeta (not quiescence) reached, and the check extensions that the bound of twice
    // maxDepth plies refused, since reset(). Tests prove the bound with them.
    int64_t maxSearchPly = 0;
    int64_t extensionsRefused = 0;
    
#ifdef BCHESS_TEST_HOOKS
    // Quiescence from the position as the search calls it at the horizon, with a window chosen by the test
    // and, when it matters, the ply it starts at and the history behind it (empty by default)
    int quiescenceForTest(ChessBoard node, int alpha, int beta, int color, MinMaxVariation &pv, int ply = 0, HistoryPtr history = nullptr) {
        Variation cv;
        return quiescence(node, history ? history : NEW_HISTORY, ply, alpha, beta, color, pv, cv);
    }
    
    // One node of alphabeta, searched as a PV node or not, from the ply and with the window the test chooses
    // (negamax: the score is for the side to move, color 1 for White)
    int alphabetaForTest(ChessBoard node, const HistoryPtr &history, TranspositionTable &table, int ply, int depthLeft, bool pvNode, int alpha, int beta, int color, MinMaxVariation &pv) {
        Variation cv;
        return alphabeta(node, history, table, ply, depthLeft, pvNode, false, alpha, beta, color, pv, cv, emptyLine);
    }
    
    // Called in the move loop right after the move has been pushed on the history. Tests use it to
    // stop the search at an exact node, or to park the search thread inside alpha-beta.
    std::function<void()> checkpoint;
#endif
    
    void reset() {
        visitedNodes = 0;
        maxPly = 0;
        pathDraws = 0;
        reductionResearches = 0;
        pvResearches = 0;
        maxSearchPly = 0;
        extensionsRefused = 0;
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
        int score = alphabeta(node, history, table, ply, config.maxDepth, true, false, -INT_MAX, INT_MAX, color, pv, currentLine, bv);
        return score * color;
    }
    
    // The same with a window, in the white-relative terms of the returned score. A score outside (alpha, beta) is a
    // bound: the true value is at or beyond it.
    int alphabeta(ChessBoard node, const HistoryPtr &history, TranspositionTable &table, int ply, bool maximizingPlayer, int alpha, int beta, Variation &pv, const Variation &bv) {
        Variation currentLine;
        int color = maximizingPlayer ? 1 : -1;
        int lo = color == 1 ? alpha : -beta, hi = color == 1 ? beta : -alpha;
        int score = alphabeta(node, history, table, ply, config.maxDepth, true, false, lo, hi, color, pv, currentLine, bv);
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
            case TranspositionEntryType::MOVE_ONLY:
                return false;
        }
        return false;
    }
    
private:
    
    // From this half-move clock on, the table does not settle a node
    static const int TT_CLOCK_LIMIT = 90;
    
    // A draw that the path decides, and not the position: a threefold repetition or the fifty-move rule. A
    // position that follows a pawn move or a capture (reversiblePlies 0) cannot repeat an earlier one.
    static bool drawnByPath(ChessBoard &node, const HistoryPtr &history) {
        return (node.reversiblePlies != 0 && ChessEvaluater::isDraw(node, history)) || ChessEvaluater::isFiftyMoveDraw(node);
    }
    
    // Whether the side has a knight, bishop, rook or queen
    static bool hasPieces(const ChessBoard &node, Color side) {
        return (node.pieces[side][KNIGHT] | node.pieces[side][BISHOP] | node.pieces[side][ROOK] | node.pieces[side][QUEEN]) != 0;
    }
    
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
    // pvNode: the node is on the principal variation (the root, and the first move of a PV node, and a move that
    // beat alpha at a PV node and is searched again). It is a flag, never computed from the window: beta - alpha
    // overflows int on the root window.
    // pv: Principal Variation - the best line found so far.
    // cv: Current Variation - the current line being examined.
    // bv: Best Variation - if available
    // https://en.wikipedia.org/wiki/Negamax
    // https://chessprogramming.wikispaces.com/Principal+variation
    int alphabeta(ChessBoard node, const HistoryPtr &history, TranspositionTable &table, int ply, int depthLeft, bool pvNode, bool afterNull, int alpha, int beta, int color, Variation &pv, Variation &cv, const Variation &bv) {
        pv.depth = ply;
        maxPly = std::max<int64_t>(maxPly, ply);
        maxSearchPly = std::max<int64_t>(maxSearchPly, ply);

        // The line cannot get any longer: the killers and the move list are sized for MAX_PLY
        if (ply >= MAX_PLY) {
            return mateAtPly(ChessEvaluater::evaluate(node) * color, ply);
        }
        
        int evalDepth = depthLeft;
        
        // The draws of the path come first, so that no table entry can stand in for them. The only repetition
        // check of the node: quiescence and evaluate trust it. A quiescence move is a capture, and no position
        // after a capture can repeat an earlier one. The root is never drawn by a rule: it is searched and
        // returns a move, whatever the history says.
        if (ply > 0 && drawnByPath(node, history)) {
            pathDraws++;
            return 0;
        }
        
        // The draws below this node that the path decided. When any was met, the value of this node belongs to
        // the path and the table gets the move only.
        int64_t pathDrawsAtEntry = pathDraws;
        
        // Check if we have the same node already in our transposition table. The table never settles the root,
        // whose line is always searched in full, nor a position near the fifty-move rule, whose clock the hash
        // does not hold (a heuristic, as in Stockfish), nor a PV node, so that the reported line is complete.
        if (config.transpositionTable && !pvNode && ply > 0 && node.halfMoveClock < TT_CLOCK_LIMIT &&
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

        if (depthLeft <= 0) {
            if (config.quiescenceSearch) {
                int score = quiescence(node, history, ply, alpha, beta, color, pv, cv);
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
        
        // Null move: pass the turn and search shallower with a zero window. When even that is above beta the node
        // is cut off. After the moves are known, so that a mate or a stalemate is scored first. Not at a PV
        // node, in check, after a null move, against a mate score, near the horizon, or with pawns and king only
        // (zugzwang). It returns beta, never a mate found after passing, and stores nothing.
        if (config.nullMove && config.alphaBetaPrunning && !pvNode && !afterNull && depthLeft >= 3 && !ChessEvaluater::isMateScore(beta) &&
            hasPieces(node, node.color) && !node.isCheck(node.color)) {
            const int reduction = depthLeft > 6 ? 3 : 2;
            auto nullNode = node;
            nullNode.moveNull();
            visitedNodes++;
            history->push_back(nullNode.getHash());
            Variation nullLine;
            int nullScore = -alphabeta(nullNode, history, table, ply + 1, depthLeft - 1 - reduction, false, true, -beta, -beta + 1, -color, nullLine, cv, emptyLine);
            history->pop_back();
            // An interrupted null search says nothing: leave at once
            if (stopped()) {
                return alpha;
            }
            if (nullScore >= beta) {
                return beta;
            }
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
        
        // Late-move reductions are for nodes that are not in check
        const bool canReduce = config.lateMoveReductions && config.principalVariationSearch && config.alphaBetaPrunning &&
                               depthLeft >= 3 && !node.isCheck(node.color);
        
        // Futility: one ply from the horizon, in a node that is not in check and is far below alpha, a quiet move
        // that gives no check is skipped (the first move is always searched). The static evaluation is the one of
        // the list that is already generated.
        bool futile = false;
        int staticEval = 0;
        if (config.futilityPruning && config.alphaBetaPrunning && depthLeft == 1 && !pvNode &&
            !ChessEvaluater::isMateScore(alpha) && !ChessEvaluater::isMateScore(beta) && !node.isCheck(node.color)) {
            staticEval = ChessEvaluater::evaluate(node, moves) * color;
            futile = staticEval + FUTILITY_MARGIN <= alpha;
        }
        bool skippedMove = false;
        
        Move bestMove = INVALID_MOVE;
        for (int index=0; index<moves.count && !stopped(); index++) {
            Move move = moves.moves[index];
            
            visitedNodes++;

            auto newNode = node;
            newNode.move(move);
            
            // Computed once per move: futility, the check extension and the reductions all read it
            const bool givesCheck = newNode.isCheck(newNode.color);
            
            if (futile && index > 0 && !MOVE_IS_CAPTURE(move) && MOVE_PROMOTION_PIECE(move) == 0 && !givesCheck) {
                skippedMove = true;
                continue;
            }
            
            cv.moves.push(move);
            history->push_back(newNode.getHash());
#ifdef BCHESS_TEST_HOOKS
            if (checkpoint) checkpoint();
#endif
            
            // After any child search that returns while the search is stopped, the history and the current line
            // are unwound and the node returns at once: the child's score is a partial value and is not used for a
            // re-search, the PV, the killers or the move order.
            auto interrupted = [&]() {
                if (!stopped()) {
                    return false;
                }
                cv.moves.pop();
                history->pop_back();
                return true;
            };
            
            Variation line;
            const Variation &bestLine = (move == bestMovePV) ? bv : emptyLine;
            // A move that gives check keeps the depth: the reply is forced, so the line is not cut off at
            // the horizon. Past twice maxDepth plies the extension stops, which bounds a perpetual check.
            bool extend = false;
            if (givesCheck) {
                if (int64_t(ply) < 2 * int64_t(config.maxDepth)) {
                    extend = true;
                } else {
                    extensionsRefused++;
                }
            }
            const int childDepth = extend ? depthLeft : depthLeft - 1;
            // The first move gets the full window. A later move gets a zero window first (alpha is a real score by
            // then, so -alpha - 1 cannot wrap) and the full window again, as a PV node, only when it lands inside
            // (alpha, beta): a zero-window result outside is already as good as the full window would say.
            int score;
            if (config.principalVariationSearch && config.alphaBetaPrunning && index > 0) {
                // A late quiet move that gives no check is searched shallower first (1 ply, 2 for a very late move
                // at depth 6 or more, never into quiescence); when it beats alpha anyway it is searched again at
                // full depth. The hash move, the captures and the killers come first in the list.
                int reduction = 0;
                if (canReduce && index >= 3 && !extend && !givesCheck && !MOVE_IS_CAPTURE(move) && MOVE_PROMOTION_PIECE(move) == 0 &&
                    move != killers[ply][0] && move != killers[ply][1]) {
                    reduction = (index >= 8 && depthLeft >= 6) ? 2 : 1;
                    if (childDepth - reduction < 1) {
                        reduction = 0;
                    }
                }
                score = -alphabeta(newNode, history, table, ply + 1, childDepth - reduction, false, false, -alpha - 1, -alpha, -color, line, cv, bestLine);
                if (interrupted()) return bestValue;
                if (reduction > 0 && score > alpha) {
                    reductionResearches++;
                    line = Variation();
                    score = -alphabeta(newNode, history, table, ply + 1, childDepth, false, false, -alpha - 1, -alpha, -color, line, cv, bestLine);
                    if (interrupted()) return bestValue;
                }
                if (pvNode && score > alpha && score < beta) {
                    pvResearches++;
                    line = Variation();
                    score = -alphabeta(newNode, history, table, ply + 1, childDepth, true, false, -beta, -alpha, -color, line, cv, bestLine);
                    if (interrupted()) return bestValue;
                }
            } else {
                score = -alphabeta(newNode, history, table, ply + 1, childDepth, pvNode && index == 0, false, -beta, -alpha, -color, line, cv, bestLine);
                if (interrupted()) return bestValue;
                // Without the zero windows a later child is searched as a non-PV node, which the table may cut
                // off. When it turns out to be the new best move at a PV node it is searched again as a PV node,
                // so that its line is complete.
                if (pvNode && index > 0 && score > alpha && score < beta) {
                    pvResearches++;
                    line = Variation();
                    score = -alphabeta(newNode, history, table, ply + 1, childDepth, true, false, -beta, -alpha, -color, line, cv, bestLine);
                    if (interrupted()) return bestValue;
                }
            }
            
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

        // Skipped moves make a fail-low an approximation, not a bound: it is below alpha, and this node's entry is the
        // move only. A cut-off stays a valid lower bound whatever was skipped. What is guaranteed is only that: the
        // approximate value still goes up to the parents, and one of them can store a bound computed from it, as with
        // any pruning (a null-move or reduced search does the same). Tracking that would change play.
        if (skippedMove && entryType != TranspositionEntryType::BETA) {
            bestValue = std::max(bestValue, staticEval);
            entryType = TranspositionEntryType::MOVE_ONLY;
        }
        
        // The store does not look at config.transpositionTable, which gates only the cut-offs above: the table
        // also orders the moves of a later search, whatever the setting.
        // A loop that was cut short holds a partial value, which must not be trusted by a later search
        // of the same position. Its parents are cut short too, so they store nothing either.
        if (ChessMoveGenerator::isValid(bestMove) && !stopped()) {
            if (pathDraws != pathDrawsAtEntry) {
                entryType = TranspositionEntryType::MOVE_ONLY;
            }
            table.store(evalDepth, node.getHash(), ttValueToStore(bestValue, ply), bestMove, entryType
#ifdef ASSERT_TT_KEY_COLLISION
                        , FFEN::getFEN(node, true)
#endif
                        );
        }

        return bestValue;
    }
    
    // Futility pruning's margin in centipawns, as delta pruning's
    static const int FUTILITY_MARGIN = 200;
    
    // Delta pruning's margin in centipawns, for what a position is worth beyond the material it wins
    static const int DELTA_MARGIN = 200;
    
    // https://chessprogramming.wikispaces.com/Quiescence+Search
    // Note: the search described in the link above returns alpha which doesn't work
    // with the positions I've been analyzing (returning alpha will never return the
    // position evaluation but rather the previous alpha and this won't work). However
    // this link shows quiescence search that returns the score, like regular negamax
    // and this is way better IMO:
    // https://www.ics.uci.edu/~eppstein/180a/990204.html
    int quiescence(ChessBoard node, const HistoryPtr &history, int depth, int alpha, int beta, int color, Variation &pv, Variation &cv) {
        pv.qsDepth = depth;
        maxPly = std::max<int64_t>(maxPly, depth);
        
        // The line cannot get any longer: the static evaluation is the answer, as in alphabeta
        if (depth >= MAX_PLY) {
            return mateAtPly(ChessEvaluater::evaluate(node) * color, depth);
        }
        
        // A side in check cannot decline to move: it has no stand-pat, and its legal moves are the evasions
        bool inCheck = node.isCheck(node.color);
        
        int standPat = 0;
        int bestValue;
        MoveList moves;
        if (inCheck) {
            moves = ChessMoveGenerator::generateMoves(node);
            if (moves.count == 0) {
                return mateAtPly(-ChessEvaluater::MAT_VALUE, depth);
            }
            bestValue = -INT_MAX;
        } else {
            standPat = mateAtPly(ChessEvaluater::evaluate(node) * color, depth);
            if (standPat >= beta) {
                return standPat;
            }
            
            if (alpha < standPat) {
                alpha = standPat;
            }
            
            moves = ChessMoveGenerator::generateQuiescenceMoves(node);
            if (moves.count == 0) {
                return standPat;
            }
            
            // Fail-soft like alphabeta: the best score so far, never below the stand-pat
            bestValue = standPat;
        }
        
        if (config.sortMoves) {
            ChessMoveGenerator::sortMoves(moves);
        }
        
        for (int index=0; index<moves.count && !stopped(); index++) {
            auto move = moves.moves[index];
            
            auto newNode = node;
            newNode.move(move);
            
            // Two prunings, with one exemption for both: a capture that gives check is never pruned, because it
            // may mate, and SEE ignores pins, so it can score a mating capture as losing. Nor is a promotion, nor
            // an evasion.
            // - Delta pruning: the capture cannot lift the score to alpha, even with a margin. Not while alpha is
            //   a mate score.
            // - SEE pruning: the capture loses material in the exchange on its square.
            if (!inCheck && MOVE_PROMOTION_PIECE(move) == 0) {
                bool hopeless = config.deltaPruning && !ChessEvaluater::isMateScore(alpha) &&
                    standPat + ChessEvaluater::pieceValue(MOVE_CAPTURED_PIECE(move)) + DELTA_MARGIN <= alpha;
                bool losing = !hopeless && config.seePruning && ChessEvaluater::see(node, move) < 0;
                if ((hopeless || losing) && !newNode.isCheck(newNode.color)) {
                    continue;
                }
            }
            
            visitedNodes++;

            cv.moves.push(move);
            history->push_back(newNode.getHash());

            // A quiet evasion can repeat a position or reach the fifty-move clock. Alpha-beta checked the node
            // that entered quiescence, so only the moves from here on are looked at.
            Variation line;
            int score;
            if (drawnByPath(newNode, history)) {
                pathDraws++;
                score = 0;
            } else {
                score = -quiescence(newNode, history, depth+1, -beta, -alpha, -color, line, cv);
            }
            
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
