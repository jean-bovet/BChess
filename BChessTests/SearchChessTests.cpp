//
//  FAlphaBetaTests.h
//  BChess
//
//  Created by Jean Bovet on 12/18/17.
//  Copyright © 2017 Jean Bovet. All rights reserved.
//

#include <gtest/gtest.h>

#include "ChessEngine.hpp"

#include "FFEN.hpp"
#include "FPGN.hpp"

#include <vector>
#include <map>

class SearchChessTests: public ::testing::Test {
public:
    void SetUp() {
        ChessEngine::initialize();
    }
};

static void assertChessSearch(int expectedVisitedNodes, int expectedValue, Configuration config, ChessBoard rootBoard = ChessBoard()) {
    ChessMinMaxSearch alphaBeta;
    alphaBeta.config = config;
    
    ChessMinMaxSearch::Variation pv;
    ChessMinMaxSearch::Variation bv;

    ASSERT_EQ(0, alphaBeta.visitedNodes);
    
    HistoryPtr history = NEW_HISTORY;
    int score = alphaBeta.alphabeta(rootBoard, history, 0, rootBoard.color == WHITE, pv, bv);
//    std::cout << alphaBeta.visitedNodes << " => " << score << " " << pv.moves.description() << std::endl;
    ASSERT_EQ(expectedVisitedNodes, alphaBeta.visitedNodes); // n initial moves + 1 for the root node
    ASSERT_EQ(expectedValue, score);
}

TEST_F(SearchChessTests, ChessTree) {
    Configuration config;
    config.quiescenceSearch = false;

    config.alphaBetaPrunning = true;
    assertChessSearch(36970, 74, config); // with alpha-beta prunning
    
    config.alphaBetaPrunning = false;
    assertChessSearch(206603, 74, config); // without alpha-beta
}

TEST_F(SearchChessTests, OrderedMove) {
    auto fen = "r1bqkbnr/pppp1ppp/2n5/3P4/8/8/PPP2PPP/RNBQKBNR b KQkq - 0 5";
    ChessBoard board;
    ASSERT_TRUE(FFEN::setFEN(fen, board));

    Configuration config;

    config.sortMoves = true;
    assertChessSearch(42568, 54, config, board);
    
    config.sortMoves = false;
    assertChessSearch(129034, 74, config, board);
}
