//
//  MinMaxSearchTests.cpp
//  BChessTests
//

#include <gtest/gtest.h>

#include "ChessEngine.hpp"
#include "FFEN.hpp"

class MinMaxSearchTests: public ::testing::Test {
public:
    void SetUp() {
        ChessEngine::initialize();
    }
};

#ifdef BCHESS_TEST_HOOKS

// A search that is cancelled in the middle of the root's move loop must not leave an entry for the
// root: that entry would carry the partial value with the full requested depth.
TEST_F(MinMaxSearchTests, CancelledLoopStoresNoEntry) {
    ChessBoard board;
    ASSERT_TRUE(FFEN::setFEN("r1bqkbnr/pppp1ppp/2n5/4p3/4P3/5N2/PPPP1PPP/RNBQKB1R w KQkq - 2 3", board));
    
    Configuration config;
    config.maxDepth = 4;
    config.transpositionTable = true;
    
    // A complete run, for reference
    MinMaxSearch complete;
    complete.config = config;
    TranspositionTable completeTable;
    MinMaxSearch::Variation pv, bv;
    int completeScore = complete.alphabeta(board, NEW_HISTORY, completeTable, 0, true, pv, bv);
    ASSERT_GT(complete.visitedNodes, 50);
    
    // The same search, cancelled at its 50th node
    MinMaxSearch search;
    search.config = config;
    TranspositionTable table;
    int calls = 0;
    search.checkpoint = [&] {
        if (++calls == 50) {
            search.cancel();
        }
    };
    MinMaxSearch::Variation pv2, bv2;
    search.alphabeta(board, NEW_HISTORY, table, 0, true, pv2, bv2);
    
    ASSERT_LT(search.visitedNodes, complete.visitedNodes);
    ASSERT_FALSE(table.exists(board.getHash()));
    
    // A later search with this table gives the same score as one with a fresh table
    search.checkpoint = nullptr;
    search.resume();
    search.reset();
    MinMaxSearch::Variation pv3, bv3;
    int score = search.alphabeta(board, NEW_HISTORY, table, 0, true, pv3, bv3);
    ASSERT_EQ(completeScore, score);
}

#endif
