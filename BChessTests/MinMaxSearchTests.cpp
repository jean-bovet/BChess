//
//  MinMaxSearchTests.cpp
//  BChessTests
//

#include <gtest/gtest.h>

#include "ChessEngine.hpp"
#include "ChessEvaluater.hpp"
#include "FFEN.hpp"

class MinMaxSearchTests: public ::testing::Test {
public:
    void SetUp() {
        ChessEngine::initialize();
    }
};

// The search at a fixed depth, with the transposition table off (a table legitimately changes results)
static int search(const char *fen, int maxDepth, bool sortMoves, MinMaxSearch::Variation &pv) {
    ChessBoard board;
    EXPECT_TRUE(FFEN::setFEN(fen, board));
    
    MinMaxSearch search;
    search.config.maxDepth = maxDepth;
    search.config.transpositionTable = false;
    search.config.sortMoves = sortMoves;
    
    TranspositionTable table;
    MinMaxSearch::Variation bv;
    return search.alphabeta(board, NEW_HISTORY, table, 0, board.color == WHITE, pv, bv);
}

static int standPat(const char *fen) {
    ChessBoard board;
    EXPECT_TRUE(FFEN::setFEN(fen, board));
    return ChessEvaluater::evaluate(board, NEW_HISTORY);
}

// Alpha-beta and quiescence return the minimax value, whatever the order the moves are tried in
TEST_F(MinMaxSearchTests, SortingDoesNotChangeTheScore) {
    struct Case { const char *fen; int maxDepth; };
    const Case cases[] = {
        {"r3k2r/p1ppqpb1/bn2pnp1/3PN3/1p2P3/2N2Q1p/PPPBBPPP/R3K2R w KQkq - 0 1", 0},
        {"r1bqkbnr/pppp1ppp/2n5/4p3/4P3/5N2/PPPP1PPP/RNBQKB1R w KQkq - 2 3", 0},
        {"r1bqkbnr/pppp1ppp/2n5/4p3/4P3/5N2/PPPP1PPP/RNBQKB1R w KQkq - 2 3", 1},
        {"r1bqkbnr/pppp1ppp/2n5/4p3/4P3/5N2/PPPP1PPP/RNBQKB1R w KQkq - 2 3", 2},
    };
    for (auto &c : cases) {
        MinMaxSearch::Variation sortedPV, unsortedPV;
        int sorted = search(c.fen, c.maxDepth, true, sortedPV);
        int unsorted = search(c.fen, c.maxDepth, false, unsortedPV);
        ASSERT_EQ(sorted, unsorted) << c.fen << " depth " << c.maxDepth;
    }
}

// Qxd7 wins a rook for free. Qxc5 (sorted last) loses the queen to bxc5, so the last capture must not
// become the result, and the best one must not be replaced by the stand-pat either.
TEST_F(MinMaxSearchTests, QuiescenceReturnsTheBestCapture) {
    auto fen = "k7/3r4/1p6/2p5/3Q4/8/8/K7 w - - 0 1";
    
    MinMaxSearch::Variation pv;
    int score = search(fen, 0, true, pv);
    
    // The value of the position after Qxd7, where Black has no capture left
    ChessBoard after;
    ASSERT_TRUE(FFEN::setFEN("k7/3Q4/1p6/2p5/8/8/8/K7 b - - 0 1", after));
    ASSERT_EQ(ChessEvaluater::evaluate(after, NEW_HISTORY), score);
    ASSERT_GT(score, standPat(fen));
    
    ASSERT_GT(pv.moves.count, 0);
    ASSERT_EQ(d4, MOVE_FROM(pv.moves.moves[0]));
    ASSERT_EQ(d7, MOVE_TO(pv.moves.moves[0]));
}

TEST_F(MinMaxSearchTests, QuiescenceNeverBelowStandPat) {
    // Qxe5 is the better capture; the last one tried (Qxc5, Qxd6) loses material
    const char *white[] = {"k7/8/3p4/2p1q3/3Q4/8/8/K7 w - - 0 1", "4k3/8/8/8/8/8/PPPP4/4K3 w - - 0 1"};
    const char *black[] = {"k7/8/8/3q4/2P1Q3/3P4/8/K7 b - - 0 1", "4k3/pppp4/8/8/8/8/8/4K3 b - - 0 1"};
    for (auto fen : white) {
        MinMaxSearch::Variation pv;
        ASSERT_GE(search(fen, 0, true, pv), standPat(fen)) << fen;
    }
    for (auto fen : black) {
        MinMaxSearch::Variation pv;
        ASSERT_LE(search(fen, 0, true, pv), standPat(fen)) << fen;
    }
}

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
