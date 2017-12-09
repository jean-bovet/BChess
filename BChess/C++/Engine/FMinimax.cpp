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
    
    MoveGenerator generator;
    MoveList moves = generator.generateMoves(board);
    if (moves.moveCount == 0) {
        // It's either a draw or mat
        if (board.isCheck(board.color)) {
            bestEvaluation.value = board.color == WHITE ? INT_MIN : INT_MAX;
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

    if (depth - 1 < line.size()) {
        lineMove = line[depth - 1];
        if (evaluateAlphaBeta(board, lineMove, depth, maxDepth, maximizing, line, alpha, beta, bestEvaluation)) {
            return bestEvaluation;
        }
    }
    
    for (int index=0; index<moves.moveCount; index++) {
        Move move = moves.moves[index];
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

bool Minimax::evaluateAlphaBeta(Board board, Move move, int depth, int maxDepth, bool maximizing, LineMove line, int &alpha, int &beta, Minimax::Evaluation &bestEvaluation) {
    if (depth == maxDepth) {
        int boardValue = Evaluate::evaluate(board);
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
