//
//  FMinimax.cpp
//  BChess
//
//  Created by Jean Bovet on 12/3/17.
//  Copyright © 2017 Jean Bovet. All rights reserved.
//

#include "FMinimax.hpp"
#include "FMoveGenerator.hpp"
#include "FEvaluate.hpp"

#include <chrono>
using namespace std::chrono;

// Minim algorithm with alpha-beta pruning and iterative deepening first search
// http://www.geeksforgeeks.org/minimax-algorithm-in-game-theory-set-1-introduction/
// http://www.geeksforgeeks.org/minimax-algorithm-in-game-theory-set-4-alpha-beta-pruning/
// https://en.wikipedia.org/wiki/Iterative_deepening_depth-first_search

inline int startValue(bool maximizing) {
    if (maximizing) {
        return INT_MIN;
    } else {
        return INT_MAX;
    }
}

inline bool isBestValue(bool maximizing, int current, int newValue) {
    if (maximizing) {
        return newValue > current;
    } else {
        return newValue < current;
    }
}

Minimax::Info Minimax::searchBestMove(Board board, int maxDepth, SearchCallback callback) {
    analyzing = true;
    
    Evaluation evaluation;
    Info info;

    if (maxDepth == -1) {
        maxDepth = INT_MAX; // infinite depth
    }
    
    for (int curMaxDepth=2; curMaxDepth<=maxDepth; curMaxDepth++) {
        if (!analyzing) {
            break;
        }
        
        evaluateCount = 0;
        
        high_resolution_clock::time_point before = high_resolution_clock::now();
        
        evaluation = evaluate(board,
                              Move(),
                              1, /* depth */
                              curMaxDepth,
                              (board.color == WHITE), /* maximize */
                              evaluation.line,
                              INT_MIN, /* alpha */
                              INT_MAX /* beta */
                              );
        high_resolution_clock::time_point after = high_resolution_clock::now();

        duration<double, std::milli> time_span = after - before;
        double diffMs = time_span.count();

        double movesPerSingleMs = evaluateCount / diffMs;
        int movesPerSecond = int(movesPerSingleMs * 1e3);

        info.depth = curMaxDepth;
        info.time = int(diffMs/1e3);
        info.evaluation = evaluation;
        info.engineColor = board.color;
        info.nodeEvaluated = evaluateCount;
        info.movesPerSecond = movesPerSecond;
        
        if (callback) {
            callback(info);
        }
    }
    return info;
}

Minimax::Evaluation Minimax::evaluate(Board board, Move move, int depth, int maxDepth, bool maximizing, LineMove line, int _alpha, int _beta) {
    Evaluation bestEvaluation;
    bestEvaluation.value = startValue(maximizing);
    bestEvaluation.color = board.color;

    if (!analyzing) {
        return bestEvaluation;
    }

    int alpha = _alpha;
    int beta = _beta;
    
    ChessMoveGenerator generator;
    MoveList moves = generator.generateMoves(board);
    if (moves.count == 0) {
        // It's either a draw or mat
        if (board.isCheck(board.color)) {
            bestEvaluation.value = board.color == WHITE ? INT_MIN : INT_MAX;
            bestEvaluation.mat = true;
        } else {
            // TODO: is that a draw??
            bestEvaluation.value = 0;
        }
        bestEvaluation.move = move;
        bestEvaluation.color = board.color;
        bestEvaluation.line.clear();
        return bestEvaluation;
    }
    
    Move lineMove = 0;

    if (depth - 1 < (int)line.size()) {
        lineMove = line[(size_t)(depth - 1)];
        if (evaluateAlphaBeta(board, lineMove, depth, maxDepth, maximizing, line, alpha, beta, bestEvaluation)) {
            return bestEvaluation;
        }
    }
    
    for (int index=0; index<moves.count; index++) {
        auto move = moves._moves[index];
        if (!analyzing) {
            break;
        }

        if (move == lineMove) {
            continue;
        }
        
        if (evaluateAlphaBeta(board, move, depth, maxDepth, maximizing, { }, alpha, beta, bestEvaluation)) {
            break;
        }
    }
    
    return bestEvaluation;
}

// Returns true if move i goes before move j.
bool captureMoveComparison (Move i, Move j) {
    if (i == j) {
        return false;
    }
    
    if (MOVE_CAPTURED_PIECE(i) > MOVE_CAPTURED_PIECE(j)) {
        return true;
    } else if (MOVE_CAPTURED_PIECE(i) == MOVE_CAPTURED_PIECE(j)) {
        return MOVE_PIECE(i) > MOVE_PIECE(j);
    } else {
        return false;
    }
}

int Minimax::quiescentSearch(Board board, int depth, bool maximizing, int alpha, int beta) {
    evaluateCount += 1;

    int stand_pat = ChessEvaluate::evaluate(board);
    
    if (maximizing) {
        alpha = std::max(alpha, stand_pat); // aka white's best score
    } else {
        beta = std::min(beta, stand_pat); // aka black's best score
    }

    if (beta <= alpha) {
        return maximizing ? alpha : beta;
    }
    
//    if (stand_pat >= beta) {
//        return beta;
//    }
//    if (alpha < stand_pat) {
//        alpha = stand_pat;
//    }
    
    bool evaluated = false;
    ChessMoveGenerator generator;
    MoveList moveList = generator.generateMoves(board);
    
    // Sort the moves according to:
    // MVV/LVA (Most Valuable Victim/Least Valuable Attacker).
    
    std::sort(std::begin(moveList._moves), std::end(moveList._moves), captureMoveComparison);
    
    for (int index=0; index<moveList.count; index++) {
        auto move = moveList._moves[index];
        
        if (!MOVE_IS_CAPTURE(move)) {
            continue;
        }
        
        evaluated = true;
        
        Board newBoard = board;
        newBoard.move(move);
        int score = quiescentSearch(newBoard, depth+1, !maximizing, alpha, beta);
        if (maximizing) {
            alpha = std::max(alpha, score);
        } else {
            beta = std::min(beta, score);
        }
        
        if (beta <= alpha) {
            return maximizing ? alpha : beta;
        }

//        if (score >= beta) {
//            return beta;
//        }
//        if (score > alpha) {
//            alpha = score;
//        }
    }
    
    return maximizing ? alpha : beta;
}

bool Minimax::evaluateAlphaBeta(Board board, Move move, int depth, int maxDepth, bool maximizing, LineMove line, int &alpha, int &beta, Minimax::Evaluation &bestEvaluation) {
    if (depth == maxDepth) {
        int boardValue = quiescentSearch(board, depth, maximizing, alpha, beta);
//        int boardValue = Evaluate::evaluate(board);
        bestEvaluation.move = move;
        bestEvaluation.value = boardValue;
        bestEvaluation.color = board.color;
        bestEvaluation.line.clear();
        return true;
    }
    
    evaluateCount += 1;
    
    Board newBoard = board;
    newBoard.move(move);
    Evaluation evaluation = evaluate(newBoard, move, depth+1, maxDepth, !maximizing, line, alpha, beta);
    if (evaluation.isValid()) {
        // Only evaluate valid evaluation. An evaluation can be invalid
        // if the evaluation has been cancelled for example.
        if (isBestValue(maximizing, bestEvaluation.value, evaluation.value)) {
            bestEvaluation.move = move;
            bestEvaluation.value = evaluation.value;
            bestEvaluation.color = evaluation.color;
            bestEvaluation.mat = evaluation.mat;

            bestEvaluation.line = evaluation.line;
            bestEvaluation.line.insert(bestEvaluation.line.begin(), move);
        }
        
        if (maximizing) {
            alpha = std::max(alpha, bestEvaluation.value);
        } else {
            beta = std::min(beta, bestEvaluation.value);
        }
    }
    
    // Returns true if the evaluation can stop because the best move has been found
    return beta <= alpha;
}
