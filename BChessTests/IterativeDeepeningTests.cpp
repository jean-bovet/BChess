//
//  IterativeDeepeningTests.cpp
//  BChessTests
//
//  The cancel and stop rules: a cancel ends the search at once, a stop always lets depth 1 finish.
//

#include <gtest/gtest.h>

#include "ChessEngine.hpp"

class IterativeDeepeningTests: public ::testing::Test {
public:
    void SetUp() {
        ChessEngine::initialize();
    }
};

TEST_F(IterativeDeepeningTests, CancelBeforeSearchIsHonored) {
    IterativeDeepening search;
    ChessBoard board;
    
    search.start();
    search.cancel();
    auto evaluation = search.search(board, NEW_HISTORY, 4, nullptr);
    
    ASSERT_EQ(0, search.minMaxSearch.visitedNodes);
    ASSERT_EQ(0, evaluation.line.count);
    ASSERT_FALSE(search.running());
}

TEST_F(IterativeDeepeningTests, StopEndsSearchAndKeepsBestLine) {
    IterativeDeepening search;
    ChessBoard board;
    
    int callbacks = 0;
    search.start();
    auto evaluation = search.search(board, NEW_HISTORY, -1, [&](ChessEvaluation) {
        callbacks++;
        if (callbacks == 2) {
            search.stop();
        }
    });
    
    // The search ended after the depth in which stop() was called, keeping that depth's line
    ASSERT_EQ(2, callbacks);
    ASSERT_GT(evaluation.line.count, 0);
    ASSERT_FALSE(search.running());
    ASSERT_FALSE(search.cancelled());
}

TEST_F(IterativeDeepeningTests, StopBeforeSearchStillFinishesDepthOne) {
    IterativeDeepening search;
    ChessBoard board;
    
    int callbacks = 0;
    search.start();
    search.stop();
    auto evaluation = search.search(board, NEW_HISTORY, -1, [&](ChessEvaluation) {
        callbacks++;
    });
    
    ASSERT_EQ(1, callbacks);
    ASSERT_GE(evaluation.line.count, 1);
    ASSERT_FALSE(search.running());
}
