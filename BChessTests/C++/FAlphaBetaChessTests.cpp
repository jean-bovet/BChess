//
//  FAlphaBetaTests.h
//  BChess
//
//  Created by Jean Bovet on 12/18/17.
//  Copyright © 2017 Jean Bovet. All rights reserved.
//

#include <gtest/gtest.h>

#include "MinMaxSearch.hpp"
#include "ChessSearch.hpp"

#include "FEvaluate.hpp"
#include "FMoveGenerator.hpp"
#include "FFEN.hpp"
#include "FPGN.hpp"

#include <vector>
#include <map>

static void assertChessSearch(int expectedVisitedNodes, int expectedValue, Configuration config) {
    config.maxDepth = 4;
    
    ChessEvaluate evaluater;
    ChessMoveGenerator moveGenerator;
    MinMaxSearch<Board, ChessMoveGenerator, ChessEvaluate, ChessEvaluation> alphaBeta(evaluater, moveGenerator, config);
    
    Board rootBoard;

    auto eval = alphaBeta.alphabeta(rootBoard, 0, INT_MIN, INT_MAX, true, false);
    std::cout << alphaBeta.visitedNodes << " => " << eval.value << std::endl;
    ASSERT_EQ(alphaBeta.visitedNodes, expectedVisitedNodes); // n initial moves + 1 for the root node
    ASSERT_EQ(eval.value, expectedValue);
}

TEST(Chess, ChessTree) {
    Configuration config;
    config.quiescenceSearch = false;

    config.alphaBetaPrunning = true;
    assertChessSearch(1278, 100, config); // with alpha-beta prunning
    
    config.alphaBetaPrunning = false;
    assertChessSearch(168421, 100, config); // without alpha-beta
}

TEST(Chess, OrderedMove) {
    auto fen = "r1bqkbnr/pppp1ppp/2n5/3P4/8/8/PPP2PPP/RNBQKBNR b KQkq - 0 5";
    Board board;
    ASSERT_TRUE(FFEN::setFEN(fen, board));
        
    Configuration config;
    config.maxDepth = 4;
    config.debugLog = false;
    ChessEvaluate evaluater;
    ChessMoveGenerator moveGenerator;
    MinMaxSearch<Board, ChessMoveGenerator, ChessEvaluate, ChessEvaluation> alphaBeta(evaluater, moveGenerator, config);

    auto eval = alphaBeta.alphabeta(board, 0, INT_MIN, INT_MAX, board.color == WHITE, false);
    std::cout << alphaBeta.visitedNodes << " => " << eval.value << " for " << eval.line.description() << std::endl;
}
