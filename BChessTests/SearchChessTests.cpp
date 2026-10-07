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
    // The counts depend on the table's collisions (the table is on in these searches), so its size is pinned
    TranspositionTable table(16);
    int score = alphaBeta.alphabeta(rootBoard, history, table, 0, rootBoard.color == WHITE, pv, bv);
//    std::cout << alphaBeta.visitedNodes << " => " << score << " " << pv.moves.description() << std::endl;
    ASSERT_EQ(expectedVisitedNodes, alphaBeta.visitedNodes); // n initial moves + 1 for the root node
    ASSERT_EQ(expectedValue, score);
}

TEST_F(SearchChessTests, ChessTree) {
    Configuration config;
    config.quiescenceSearch = false;

    config.alphaBetaPrunning = true;
    assertChessSearch(4886, 0, config); // with alpha-beta prunning
    
    config.alphaBetaPrunning = false;
    assertChessSearch(142706, 0, config); // without alpha-beta
}

TEST_F(SearchChessTests, OrderedMove) {
    auto fen = "r1bqkbnr/pppp1ppp/2n5/3P4/8/8/PPP2PPP/RNBQKBNR b KQkq - 0 5";
    ChessBoard board;
    ASSERT_TRUE(FFEN::setFEN(fen, board));

    Configuration config;
    config.deltaPruning = false; // the counts are those of plain alpha-beta with quiescence

    // Quiescence in check (ENGINE-3 search step 4) changed the counts from 16437 and 341919: the evasions of
    // a side in check are searched where the stand-pat used to end the line
    config.sortMoves = true;
    assertChessSearch(19296, 50, config, board);
    
    config.sortMoves = false;
    assertChessSearch(1611681, 50, config, board);
}
