//
//  Handicap.hpp
//  BChess
//
//  The strength levels below full strength: every legal root move is scored by the engine's own search to a
//  shallow depth, and one of the best is chosen at random. See planning/APP-3-strength-levels.md.
//

#pragma once

#include <algorithm>
#include <chrono>
#include <cmath>
#include <cstdint>
#include <random>
#include <vector>

#include "ChessEvaluation.hpp"
#include "ChessEvaluater.hpp"
#include "ChessMoveGenerator.hpp"
#include "IterativeDeepening.hpp"
#include "MinMaxSearch.hpp"
#include "TranspositionTable.hpp"

enum class Strength { beginner, casual, club, strong, maximum };

// The only place the levels are tuned.
struct Handicap {
    int depth;          // each root move is scored by a search of depth - 1 after it
    int temperature;    // centipawns: how readily a move below the best is played
    double blindness;   // the chance that a move is chosen with no quiescence search
    
    // Not called for maximum
    static Handicap of(Strength strength) {
        switch (strength) {
            case Strength::beginner: return {1, 10, 0.1};
            case Strength::casual:   return {2, 25, 0.2};
            case Strength::club:     return {3, 25, 0.0};
            case Strength::strong:   return {5, 8, 0.0};
            case Strength::maximum:  break;
        }
        return {5, 8, 0.0};
    }
};

// Which of the scores to play. The scores are from the side to move's point of view, raw (a mate is not clamped),
// and never empty. u is in [0, 1). A move is a candidate when it is within 4 temperatures of the best, with the
// weight exp((score - best) / temperature). A mate is far beyond any window, so a found mate is played, a move
// that walks into a mate is not played while another exists, and a large advantage keeps its order.
inline int chooseRootMove(const std::vector<int> &scores, int temperature, double u) {
    int best = *std::max_element(scores.begin(), scores.end());
    int window = 4 * std::max(temperature, 1);
    double t = std::max(temperature, 1);
    
    double total = 0;
    int last = 0;
    std::vector<double> weights(scores.size(), 0.0);
    for (size_t index = 0; index < scores.size(); index++) {
        int difference = scores[index] - best; // at most about 2 * MAT_VALUE, so no overflow
        if (difference >= -window) {
            weights[index] = std::exp(double(difference) / t);
            total += weights[index];
            last = int(index);
        }
    }
    
    double target = u * total;
    double cumulative = 0;
    for (size_t index = 0; index < scores.size(); index++) {
        if (weights[index] > 0) {
            cumulative += weights[index];
            if (cumulative > target) {
                return int(index);
            }
        }
    }
    return last;
}

class HandicappedSearch {
public:
    struct ScoredMove {
        Move move;
        int score = 0;          // white-relative, as MinMaxSearch::alphabeta returns it
        MinMaxSearch::Variation pv;
        int64_t nodes = 0;
        int64_t maxPly = 0;
    };
    
    // Scores every legal move of the root by a search of `maxDepth` plies after it (0: quiescence only), from the
    // ply 1, so that the repetition and fifty-move rules apply to the child. Uses a table of its own, so that the
    // shared table neither lifts the depth nor receives values that were computed without quiescence. Stops
    // early, with fewer moves than the root has, when the search is cancelled.
    static std::vector<ScoredMove> scoreRootMoves(IterativeDeepening &iterative, ChessBoard root, HistoryPtr history, int maxDepth, bool quiescence) {
        std::vector<ScoredMove> result;
        MinMaxSearch &minMax = iterative.minMaxSearch;
        
        auto moves = ChessMoveGenerator::generateMoves(root);
        if (moves.count == 0) {
            return result;
        }
        
        TranspositionTable table(1);
        minMax.clearKillers();
        
        const int savedDepth = minMax.config.maxDepth;
        const bool savedQuiescence = minMax.config.quiescenceSearch;
        minMax.config.maxDepth = maxDepth;
        minMax.config.quiescenceSearch = quiescence;
        
        for (int index = 0; index < moves.count; index++) {
            ScoredMove scored;
            scored.move = moves.moves[index];
            
            ChessBoard child = root;
            child.move(scored.move);
            history->push_back(child.getHash());
            
            minMax.reset();
            scored.score = minMax.alphabeta(child, history, table, 1, child.color == WHITE, scored.pv, MinMaxSearch::emptyLine);
            scored.nodes = minMax.visitedNodes;
            scored.maxPly = minMax.maxPly;
            
            history->pop_back();
            
            if (iterative.cancelled()) {
                break;
            }
            result.push_back(std::move(scored));
        }
        
        minMax.config.maxDepth = savedDepth;
        minMax.config.quiescenceSearch = savedQuiescence;
        return result;
    }
    
    // A number in [0, 1) from the generator
    static double unit(std::mt19937_64 &random) {
        return double(random() >> 11) * (1.0 / 9007199254740992.0);
    }
    
    // Chooses the move of a handicapped level. Like IterativeDeepening::search, it returns the evaluation, with an
    // empty line when the root has no move or the search was cancelled. A stop() does not cut it short.
    static ChessEvaluation search(IterativeDeepening &iterative, ChessBoard board, HistoryPtr history, Handicap handicap, std::mt19937_64 &random) {
        auto start = std::chrono::steady_clock::now();
        auto elapsedMilli = [&] {
            return int64_t(std::chrono::duration_cast<std::chrono::milliseconds>(std::chrono::steady_clock::now() - start).count());
        };
        
        ChessEvaluation evaluation;
        evaluation.engineColor = board.color;
        evaluation.depth = handicap.depth;
        
        // Drawn once per move
        bool blind = unit(random) < handicap.blindness;
        double u = unit(random);
        
        auto scored = scoreRootMoves(iterative, board, history, std::max(handicap.depth - 1, 0), !blind);
        
        auto finish = [&] {
            evaluation.time = elapsedMilli();
            evaluation.movesPerSecond = IterativeDeepening::nodesPerSecond(evaluation.nodes, evaluation.time);
            IterativeDeepening::Status expected = IterativeDeepening::Status::running;
            iterative.status.compare_exchange_strong(expected, IterativeDeepening::Status::stopped);
            return evaluation;
        };
        
        if (scored.empty() || iterative.cancelled()) {
            return finish();
        }
        
        int sign = board.color == WHITE ? 1 : -1;
        std::vector<int> own;
        evaluation.nodes = int64_t(scored.size());
        int64_t deepest = 0;
        for (auto &entry : scored) {
            own.push_back(entry.score * sign);
            evaluation.nodes += entry.nodes;
            deepest = std::max(deepest, entry.maxPly);
        }
        evaluation.selDepth = int(deepest);
        
        auto &chosen = scored[chooseRootMove(own, handicap.temperature, u)];
        evaluation.value = chosen.score;
        evaluation.quiescenceDepth = chosen.pv.qsDepth;
        evaluation.line.push(chosen.move);
        evaluation.line.push(chosen.pv.moves);
        return finish();
    }
};
