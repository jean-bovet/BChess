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
    return ChessEvaluater::evaluate(board);
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
    ASSERT_EQ(ChessEvaluater::evaluate(after), score);
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

// The search with an explicit table, so that a test can share one between searches.
static int searchWithTable(const char *fen, int maxDepth, bool useTable, TranspositionTable &table, MinMaxSearch::Variation &pv, MinMaxSearch *used = nullptr) {
    ChessBoard board;
    EXPECT_TRUE(FFEN::setFEN(fen, board));
    
    MinMaxSearch search;
    search.config.maxDepth = maxDepth;
    search.config.transpositionTable = useTable;
    
    MinMaxSearch::Variation bv;
    int score = search.alphabeta(board, NEW_HISTORY, table, 0, board.color == WHITE, pv, bv);
    if (used) {
        used->visitedNodes = search.visitedNodes;
        used->maxPly = search.maxPly;
    }
    return score;
}

static const int mate = ChessEvaluater::MAT_VALUE;

// White mates in 1 and in 2; the same positions with the colours swapped give the negative scores
static const char *mateIn1White = "6k1/5ppp/8/8/8/8/8/R5K1 w - - 0 1";
static const char *mateIn1Black = "r5k1/8/8/8/8/8/5PPP/6K1 b - - 0 1";
static const char *mateIn2White = "7k/8/5K2/8/8/8/8/R7 w - - 0 1"; // Kg6 (or Ra7) and Ra8#
static const char *mateIn2Black = "1r6/K1k5/8/8/8/8/8/8 b - - 1 2";

// A mate is worth less the further it is from the root: the search then prefers the shorter one
TEST_F(MinMaxSearchTests, MateCarriesDistance) {
    for (bool useTable : {false, true}) {
        TranspositionTable table;
        MinMaxSearch::Variation pv;
        ASSERT_EQ(mate - 1, searchWithTable(mateIn1White, 3, useTable, table, pv)) << useTable;
        
        TranspositionTable table2;
        MinMaxSearch::Variation pv2;
        ASSERT_EQ(-(mate - 1), searchWithTable(mateIn1Black, 3, useTable, table2, pv2)) << useTable;
        
        TranspositionTable table3;
        MinMaxSearch::Variation pv3;
        ASSERT_EQ(mate - 3, searchWithTable(mateIn2White, 4, useTable, table3, pv3)) << useTable;
        
        TranspositionTable table4;
        MinMaxSearch::Variation pv4;
        ASSERT_EQ(-(mate - 3), searchWithTable(mateIn2Black, 4, useTable, table4, pv4)) << useTable;
    }
}

TEST_F(MinMaxSearchTests, MateScoreHelpers) {
    ASSERT_TRUE(ChessEvaluater::isMateScore(mate));
    ASSERT_TRUE(ChessEvaluater::isMateScore(-(mate - 7)));
    ASSERT_FALSE(ChessEvaluater::isMateScore(0));
    ASSERT_FALSE(ChessEvaluater::isMateScore(5000));
    ASSERT_FALSE(ChessEvaluater::isMateScore(-(mate - ChessEvaluater::MAX_MATE_PLY)));
    ASSERT_EQ(3, ChessEvaluater::matePlies(mate - 3));
    ASSERT_EQ(3, ChessEvaluater::matePlies(-(mate - 3)));
    ASSERT_EQ(0, ChessEvaluater::matePlies(120));
}

// Qg7# mates at once, Qf3 (or Qf8+) mates later: with equal scores the first one found won
TEST_F(MinMaxSearchTests, PrefersShorterMate) {
    TranspositionTable table;
    MinMaxSearch::Variation pv;
    int score = searchWithTable("7k/5Q2/6K1/8/8/8/8/8 w - - 0 1", 4, false, table, pv);
    ASSERT_EQ(mate - 1, score);
    ASSERT_GT(pv.moves.count, 0);
    ASSERT_EQ(f7, MOVE_FROM(pv.moves.moves[0]));
    ASSERT_EQ(g7, MOVE_TO(pv.moves.moves[0]));
}

// P: White to move, mate in 2. Q: Black to move, its only move leads to P (the rook checks, only Ka2 escapes).
// All scores are White's, as alphabeta returns them.
TEST_F(MinMaxSearchTests, TTMateIsPlyRelative) {
    const char *P = "8/8/8/8/8/8/k1K5/1R6 w - - 1 2";
    const char *Q = "8/8/8/8/8/8/2K5/kR6 b - - 0 1";
    const char *Pm = "1r6/K1k5/8/8/8/8/8/8 b - - 1 2";
    const char *Qm = "Kr6/2k5/8/8/8/8/8/8 w - - 0 1";
    struct Case { const char *p; const char *q; int sign; };
    for (auto c : {Case{P, Q, 1}, Case{Pm, Qm, -1}}) {
        // (a) the table holds P (stored at ply 0), Q probes it at ply 1
        {
            TranspositionTable table;
            MinMaxSearch::Variation pv1, pv2;
            ASSERT_EQ(c.sign * (mate - 3), searchWithTable(c.p, 4, true, table, pv1));
            ASSERT_EQ(c.sign * (mate - 4), searchWithTable(c.q, 5, true, table, pv2)) << c.q;
        }
        // (b) Q stores P at ply 1, the root probe of P at ply 0 reads it back
        {
            TranspositionTable table;
            MinMaxSearch::Variation pv1, pv2;
            ASSERT_EQ(c.sign * (mate - 4), searchWithTable(c.q, 5, true, table, pv1)) << c.q;
            ASSERT_EQ(c.sign * (mate - 3), searchWithTable(c.p, 4, true, table, pv2));
        }
    }
}

// ALPHA and BETA entries are compared with the window in root-relative values. The stored value is relative to its
// node: at ply 3 a stored mate of MAT-1 is a mate of MAT-4 from the root. Windows sit between the two values, so
// comparing the stored value as it is gives the opposite answer.
TEST_F(MinMaxSearchTests, TTBoundsUseRootRelativeMates) {
    const int ply = 3;
    auto entry = [](int value, TranspositionEntryType type) {
        TranspositionEntry e = {};
        e.value = value;
        e.type = type;
        return e;
    };
    int value = 0;
    
    // A winning mate stored as MAT-1 reads MAT-4 at ply 3
    int stored = mate - 1;
    int fromRoot = mate - 4;
    // BETA: a cutoff only when the root-relative value reaches beta
    ASSERT_FALSE(MinMaxSearch::ttCutoff(entry(stored, BETA), ply, 0, fromRoot + 1, value));
    ASSERT_EQ(fromRoot, value);
    ASSERT_TRUE(MinMaxSearch::ttCutoff(entry(stored, BETA), ply, 0, fromRoot, value));
    // ALPHA: a cutoff only when the root-relative value is at most alpha
    ASSERT_FALSE(MinMaxSearch::ttCutoff(entry(stored, ALPHA), ply, fromRoot - 1, mate, value));
    ASSERT_TRUE(MinMaxSearch::ttCutoff(entry(stored, ALPHA), ply, fromRoot, mate, value));
    
    // A losing mate: -(MAT-1) reads -(MAT-4)
    int lost = -(mate - 1);
    int lostFromRoot = -(mate - 4);
    ASSERT_FALSE(MinMaxSearch::ttCutoff(entry(lost, BETA), ply, -mate, lostFromRoot + 1, value));
    ASSERT_EQ(lostFromRoot, value);
    ASSERT_TRUE(MinMaxSearch::ttCutoff(entry(lost, BETA), ply, -mate, lostFromRoot, value));
    ASSERT_FALSE(MinMaxSearch::ttCutoff(entry(lost, ALPHA), ply, lostFromRoot - 1, mate, value));
    ASSERT_TRUE(MinMaxSearch::ttCutoff(entry(lost, ALPHA), ply, lostFromRoot, mate, value));
    
    // Scores that are not mates are never adjusted, and an exact entry always settles the node
    ASSERT_TRUE(MinMaxSearch::ttCutoff(entry(250, BETA), ply, 0, 250, value));
    ASSERT_EQ(250, value);
    ASSERT_FALSE(MinMaxSearch::ttCutoff(entry(250, BETA), ply, 0, 251, value));
    ASSERT_TRUE(MinMaxSearch::ttCutoff(entry(stored, EXACT), ply, 0, mate, value));
    ASSERT_EQ(fromRoot, value);
}

// The deepest ply visited, in the search or in the quiescence search, not the depth of the principal variation
TEST_F(MinMaxSearchTests, SelDepthIsDeepestVisited) {
    TranspositionTable table;
    MinMaxSearch::Variation pv;
    MinMaxSearch used;
    searchWithTable("r1bqkb1r/pppp1ppp/2n2n2/4p3/2B1P3/3P1N2/PPP2PPP/RNBQK2R w KQkq - 0 1", 2, false, table, pv, &used);
    // The line that was chosen ends at ply 2 (qsDepth), and a capture sequence elsewhere runs much deeper
    ASSERT_EQ(2, pv.qsDepth);
    ASSERT_GT(used.maxPly, pv.qsDepth);
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

// Iterative deepening to `depth` with the transposition table never read. Fills the score and the cumulative
// node count of every depth.
static void iterate(const char *fen, int depth, bool sortMoves, std::vector<int> &scores, std::vector<int64_t> &nodes) {
    ChessBoard board;
    EXPECT_TRUE(FFEN::setFEN(fen, board));
    
    IterativeDeepening search;
    search.minMaxSearch.config.transpositionTable = false;
    search.minMaxSearch.config.sortMoves = sortMoves;
    search.start();
    search.search(board, NEW_HISTORY, depth, [&](ChessEvaluation e) {
        scores.push_back(e.value);
        nodes.push_back(e.nodes);
    });
}

// Ordering moves only changes how soon alpha-beta cuts off, never the minimax value: with the table never
// read for cut-offs, iterative deepening gives the same score at every depth whatever the order
TEST_F(MinMaxSearchTests, OrderingDoesNotChangeTheScore) {
    struct Case { const char *fen; int depth; };
    const Case cases[] = {
        {"r3k2r/p1ppqpb1/bn2pnp1/3PN3/1p2P3/2N2Q1p/PPPBBPPP/R3K2R w KQkq - 0 1", 2},
        {"r1bqkb1r/pppp1ppp/2n2n2/4p3/2B1P3/5N2/PPPP1PPP/RNBQK2R w KQkq - 4 4", 2},
        {"r1bqkbnr/pppp1ppp/2n5/3P4/8/8/PPP2PPP/RNBQKBNR b KQkq - 0 5", 3},
    };
    for (auto &c : cases) {
        std::vector<int> sortedScores, unsortedScores;
        std::vector<int64_t> sortedNodes, unsortedNodes;
        iterate(c.fen, c.depth, true, sortedScores, sortedNodes);
        iterate(c.fen, c.depth, false, unsortedScores, unsortedNodes);
        ASSERT_EQ(size_t(c.depth), sortedScores.size()) << c.fen;
        ASSERT_EQ(sortedScores, unsortedScores) << c.fen;
    }
}

// sortMoves = false turns the MVV/LVA sort and the table's hash move off, and nothing else: the previous
// iteration's best variation is still tried first, so the unsorted node counts are the plain baseline
TEST_F(MinMaxSearchTests, UnsortedSearchKeepsBestVariationFirst) {
    std::vector<int> scores;
    std::vector<int64_t> nodes;
    iterate("r1bqkbnr/pppp1ppp/2n5/3P4/8/8/PPP2PPP/RNBQKBNR b KQkq - 0 5", 3, false, scores, nodes);
    // Recorded before the hash move existed (ENGINE-3 step 6): the cumulative nodes of depths 1 to 3
    ASSERT_EQ((std::vector<int64_t>{95, 1065, 40717}), nodes);
}

// An entry that a collision or an old game left under this position's hash can name any move: the move
// is searched first only when the position has it
TEST_F(MinMaxSearchTests, BogusHashMoveIsIgnored) {
    const char *fen = "r1bqkbnr/pppp1ppp/2n5/4p3/4P3/5N2/PPPP1PPP/RNBQKB1R w KQkq - 2 3";
    ChessBoard board;
    ASSERT_TRUE(FFEN::setFEN(fen, board));
    
    TranspositionTable fresh;
    MinMaxSearch::Variation freshPV;
    int freshScore = searchWithTable(fen, 3, false, fresh, freshPV);
    
    // A rook that jumps over its own pieces to take the queen (a win of material, if it were played), and a
    // king capture that is not legal either
    for (Move bogus : {createCapture(a1, d8, WHITE, ROOK, BLACK, QUEEN), createCapture(e1, e8, WHITE, KING, BLACK, KING)}) {
        TranspositionTable poisoned;
        poisoned.store(7, board.getHash(), 0, bogus, TranspositionEntryType::EXACT);
        MinMaxSearch::Variation pv;
        int score = searchWithTable(fen, 3, false, poisoned, pv);
        ASSERT_EQ(freshScore, score);
        
        auto legal = ChessMoveGenerator::generateMoves(board);
        bool found = false;
        for (int i = 0; i < legal.count; i++) {
            found = found || legal.moves[i] == pv.moves.bestMove();
        }
        ASSERT_TRUE(found) << "the first move of the line is legal";
    }
}

// A killer is a quiet move that cut the search off at its ply: never a capture or a promotion, at most two per
// ply, and the two differ
TEST_F(MinMaxSearchTests, KillerIsAQuietMove) {
    ChessBoard board;
    ASSERT_TRUE(FFEN::setFEN("r1bqkb1r/pppp1ppp/2n2n2/4p3/2B1P3/5N2/PPPP1PPP/RNBQK2R w KQkq - 4 4", board));
    IterativeDeepening search;
    search.minMaxSearch.config.transpositionTable = false;
    search.start();
    search.search(board, NEW_HISTORY, 4, nullptr);
    
    int recorded = 0;
    for (int ply = 0; ply < MinMaxSearch::MAX_PLY; ply++) {
        Move first = search.minMaxSearch.killers[ply][0];
        Move second = search.minMaxSearch.killers[ply][1];
        if (!MOVE_ISVALID(first)) {
            ASSERT_FALSE(MOVE_ISVALID(second)) << "a second killer without a first, ply " << ply;
            continue;
        }
        for (Move killer : {first, second}) {
            if (!MOVE_ISVALID(killer)) continue;
            recorded++;
            ASSERT_FALSE(MOVE_IS_CAPTURE(killer)) << "ply " << ply;
            ASSERT_EQ(0, (int)MOVE_PROMOTION_PIECE(killer)) << "ply " << ply;
        }
        ASSERT_NE(first, second) << "ply " << ply;
    }
    ASSERT_GT(recorded, 0);
    
    // Starting a search clears them
    search.start();
    search.search(board, NEW_HISTORY, 1, nullptr);
    ASSERT_FALSE(MOVE_ISVALID(search.minMaxSearch.killers[3][0]));
}
