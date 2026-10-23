//
//  IterativeDeepeningTests.cpp
//  BChessTests
//
//  The cancel and stop rules: a cancel ends the search at once, a stop always lets depth 1 finish.
//

#include <gtest/gtest.h>

#include <memory>
#include <vector>

#include "ChessEngine.hpp"
#include "FFEN.hpp"

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

static const char *middlegame = "r1bqkbnr/pppp1ppp/2n5/4p3/4P3/5N2/PPPP1PPP/RNBQKB1R w KQkq - 2 3";

TEST_F(IterativeDeepeningTests, StatisticsAreCumulative) {
    IterativeDeepening search;
    ChessBoard board;
    ASSERT_TRUE(FFEN::setFEN(middlegame, board));
    
    std::vector<ChessEvaluation> reported;
    int64_t visitedPerDepth = 0;
    search.start();
    auto evaluation = search.search(board, NEW_HISTORY, 3, [&](ChessEvaluation e) {
        reported.push_back(e);
        visitedPerDepth += search.minMaxSearch.visitedNodes;
    });
    
    ASSERT_EQ(3u, reported.size());
    for (size_t i = 0; i < reported.size(); i++) {
        ASSERT_EQ(int(i) + 1, reported[i].depth);
        if (i > 0) {
            ASSERT_GT(reported[i].nodes, reported[i - 1].nodes);
            ASSERT_GE(reported[i].time, reported[i - 1].time);
        }
    }
    ASSERT_EQ(visitedPerDepth, reported.back().nodes);
    // Nothing was interrupted: the final totals are the last depth's
    ASSERT_EQ(reported.back().nodes, evaluation.nodes);
    ASSERT_GE(evaluation.time, reported.back().time);
    ASSERT_GE(evaluation.selDepth, evaluation.depth);
}

#ifdef BCHESS_TEST_HOOKS

// Stops the search at the `node`th checkpoint of the given depth
static void stopInDepth(IterativeDeepening &search, int depth, int node) {
    auto calls = std::make_shared<int>(0);
    search.minMaxSearch.checkpoint = [&search, depth, node, calls] {
        if (search.minMaxSearch.config.maxDepth == depth && ++*calls == node) {
            search.stop();
        }
    };
}

TEST_F(IterativeDeepeningTests, NoCallbackForInterruptedDepth) {
    IterativeDeepening search;
    ChessBoard board;
    ASSERT_TRUE(FFEN::setFEN(middlegame, board));
    
    std::vector<ChessEvaluation> reported;
    search.start();
    stopInDepth(search, 2, 5);
    search.search(board, NEW_HISTORY, -1, [&](ChessEvaluation e) {
        reported.push_back(e);
    });
    
    ASSERT_EQ(1u, reported.size());
    ASSERT_EQ(1, reported[0].depth);
}

TEST_F(IterativeDeepeningTests, FinalStatsIncludeInterruptedDepth) {
    IterativeDeepening search;
    ChessBoard board;
    ASSERT_TRUE(FFEN::setFEN(middlegame, board));
    
    std::vector<ChessEvaluation> reported;
    search.start();
    stopInDepth(search, 3, 20);
    auto evaluation = search.search(board, NEW_HISTORY, 3, [&](ChessEvaluation e) {
        reported.push_back(e);
    });
    
    // Depth 3 never completed: score and line are depth 2's
    ASSERT_EQ(2u, reported.size());
    ASSERT_EQ(2, evaluation.depth);
    ASSERT_EQ(reported[1].value, evaluation.value);
    ASSERT_EQ(reported[1].line.count, evaluation.line.count);
    for (int i = 0; i < evaluation.line.count; i++) {
        ASSERT_EQ(reported[1].line.moves[i], evaluation.line.moves[i]);
    }
    
    // The work of the interrupted depth is counted
    int64_t extra = search.minMaxSearch.visitedNodes;
    ASSERT_GT(extra, 0);
    ASSERT_EQ(reported[1].nodes + extra, evaluation.nodes);
    ASSERT_GE(evaluation.time, reported[1].time);
    
    // The deepest ply of the whole search, the interrupted depth included
    int64_t interruptedPly = search.minMaxSearch.maxPly;
    ASSERT_EQ(std::max<int64_t>(reported[1].selDepth, interruptedPly), evaluation.selDepth);
    ASSERT_GE(evaluation.selDepth, reported[0].selDepth);
}

// The depth that is interrupted reached plies that the completed depth did not: seldepth covers them
TEST_F(IterativeDeepeningTests, FinalSelDepthIncludesInterruptedDepth) {
    IterativeDeepening search;
    ChessBoard board;
    ASSERT_TRUE(FFEN::setFEN(middlegame, board));
    
    std::vector<ChessEvaluation> reported;
    search.start();
    stopInDepth(search, 2, 100);
    auto evaluation = search.search(board, NEW_HISTORY, 2, [&](ChessEvaluation e) {
        reported.push_back(e);
    });
    
    ASSERT_EQ(1u, reported.size());
    ASSERT_GT(search.minMaxSearch.maxPly, reported[0].selDepth);
    ASSERT_EQ(search.minMaxSearch.maxPly, evaluation.selDepth);
}

#endif

TEST_F(IterativeDeepeningTests, NpsWithZeroTime) {
    ASSERT_EQ(0, IterativeDeepening::nodesPerSecond(1000, 0));
    ASSERT_EQ(0, IterativeDeepening::nodesPerSecond(0, 0));
    ASSERT_EQ(2000, IterativeDeepening::nodesPerSecond(1000, 500));
    // More than 2^31 nodes do not wrap
    int64_t nodes = 5000000000LL;
    ASSERT_EQ(5000000000LL, IterativeDeepening::nodesPerSecond(nodes, 1000));
}

#ifdef BCHESS_TEST_HOOKS
// A stop in the middle of an aspiration re-search: the search returns, nothing is reported for that depth, the line
// of the previous depth is kept, and the re-search is not started again. The position fails low at depth 6
// (-475 to -550) with the pruning that bets off.
TEST_F(IterativeDeepeningTests, StopDuringAspirationResearch) {
    ChessBoard board;
    ASSERT_TRUE(FFEN::setFEN("r3k2r/Pppp1ppp/1b3nbN/nP6/BBP1P3/q4N2/Pp1P2PP/R2Q1RK1 w kq - 0 1", board));
    IterativeDeepening search;
    search.minMaxSearch.config.transpositionTable = false;
    search.minMaxSearch.config.deltaPruning = false;
    search.minMaxSearch.config.seePruning = false;
    search.minMaxSearch.config.nullMove = false;
    search.minMaxSearch.config.lateMoveReductions = false;
    search.minMaxSearch.config.futilityPruning = false;
    
    bool stopped = false;
    search.minMaxSearch.checkpoint = [&] {
        if (!stopped && search.aspirationResearches >= 1) {
            stopped = true;
            search.stop();
        }
    };
    std::vector<int> depths;
    search.start();
    ChessEvaluation result = search.search(board, NEW_HISTORY, 8, [&](ChessEvaluation e) { depths.push_back(e.depth); });
    search.minMaxSearch.checkpoint = nullptr;
    
    ASSERT_TRUE(stopped);
    ASSERT_EQ(1, search.aspirationResearches.load());
    ASSERT_FALSE(depths.empty());
    ASSERT_EQ(5, depths.back());
    ASSERT_EQ(5, result.depth);
    ASSERT_GT(result.line.count, 0);
    
    // The same when the stop comes in the first attempt of depth 6: nothing is repeated, the line of depth 5 is kept
    IterativeDeepening first;
    first.minMaxSearch.config.transpositionTable = false;
    first.minMaxSearch.config.deltaPruning = false;
    first.minMaxSearch.config.seePruning = false;
    first.minMaxSearch.config.nullMove = false;
    first.minMaxSearch.config.lateMoveReductions = false;
    first.minMaxSearch.config.futilityPruning = false;
    bool stoppedFirst = false;
    first.minMaxSearch.checkpoint = [&] {
        if (!stoppedFirst && first.minMaxSearch.config.maxDepth == 6) {
            stoppedFirst = true;
            first.stop();
        }
    };
    depths.clear();
    first.start();
    ChessEvaluation firstResult = first.search(board, NEW_HISTORY, 8, [&](ChessEvaluation e) { depths.push_back(e.depth); });
    first.minMaxSearch.checkpoint = nullptr;
    ASSERT_TRUE(stoppedFirst);
    ASSERT_EQ(0, first.aspirationResearches.load());
    ASSERT_EQ(5, depths.back());
    ASSERT_EQ(5, firstResult.depth);
}
#endif

// The principal variation, with every default on, is a legal line from the root: each move is among the moves of
// the position it is played from, and the line is as long as the depth unless it ends in a mate.
TEST_F(IterativeDeepeningTests, PrincipalVariationReplaysLegally) {
    const char *fens[] = {
        "rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1",
        "r3k2r/p1ppqpb1/bn2pnp1/3PN3/1p2P3/2N2Q1p/PPPBBPPP/R3K2R w KQkq - 0 1",
        "8/2p5/3p4/KP5r/1R3p1k/8/4P1P1/8 w - - 0 1",
        "r3k2r/Pppp1ppp/1b3nbN/nP6/BBP1P3/q4N2/Pp1P2PP/R2Q1RK1 w kq - 0 1",
        "rnbq1k1r/pp1Pbppp/2p5/8/2B5/8/PPP1NnPP/RNBQK2R w KQ - 1 8",
        "r4rk1/1pp1qppp/p1np1n2/2b1p1B1/2B1P1b1/P1NP1N2/1PP1QPPP/R4RK1 w - - 0 10",
        "r1bq1rk1/ppp2ppp/2n2n2/3pp3/1bB1P3/2NP1N2/PPP2PPP/R1BQ1RK1 w - - 0 7",
        "r1bqkb1r/pppp1ppp/2n2n2/4p3/2B1P3/5N2/PPPP1PPP/RNBQK2R w KQkq - 4 4",
    };
    for (const char *fen : fens) {
        ChessBoard board;
        ASSERT_TRUE(FFEN::setFEN(fen, board));
        IterativeDeepening search;
        search.start();
        ChessEvaluation result = search.search(board, NEW_HISTORY, 6, [](ChessEvaluation) {});
        ASSERT_GT(result.line.count, 0) << fen;
        if (!ChessEvaluater::isMateScore(result.value)) {
            ASSERT_GE(result.line.count, 6) << fen;
        }
        ChessBoard replay = board;
        for (int i = 0; i < result.line.count; i++) {
            auto legal = ChessMoveGenerator::generateMoves(replay);
            bool found = false;
            for (int m = 0; m < legal.count; m++) {
                found = found || legal.moves[m] == result.line.moves[i];
            }
            ASSERT_TRUE(found) << fen << " move " << i;
            replay.move(result.line.moves[i]);
        }
    }
}
