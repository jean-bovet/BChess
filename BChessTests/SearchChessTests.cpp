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
    // The recorded counts are those of plain alpha-beta (ENGINE-3 search step 6 added zero windows)
    alphaBeta.config.principalVariationSearch = false;
    alphaBeta.config.nullMove = false;
    alphaBeta.config.lateMoveReductions = false;
    alphaBeta.config.futilityPruning = false;
    alphaBeta.config.seePruning = false;
    
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
    assertChessSearch(5605, 0, config); // with alpha-beta prunning (4886 before the check extension, ENGINE-3 search step 5)
    
    config.alphaBetaPrunning = false;
    assertChessSearch(146059, 0, config); // without alpha-beta (142706 before it)
}

TEST_F(SearchChessTests, OrderedMove) {
    auto fen = "r1bqkbnr/pppp1ppp/2n5/3P4/8/8/PPP2PPP/RNBQKBNR b KQkq - 0 5";
    ChessBoard board;
    ASSERT_TRUE(FFEN::setFEN(fen, board));

    Configuration config;
    config.deltaPruning = false; // the counts are those of plain alpha-beta with quiescence

    // Quiescence in check (ENGINE-3 search step 4) changed the counts from 16437 and 341919: the evasions of
    // a side in check are searched where the stand-pat used to end the line. The check extension (step 5) changed
    // them again, from 19296 and 1611681; the PV re-search of a later best child (PVS off, review round 1) from
    // 37408 and 18230535 (ChessTree above: from 5142 and 145596).
    config.sortMoves = true;
    assertChessSearch(38161, 25, config, board);
    
    config.sortMoves = false;
    assertChessSearch(18239934, 25, config, board);
}
