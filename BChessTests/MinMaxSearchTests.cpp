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

// At MAX_PLY the search returns the static evaluation before visiting a move, and one ply earlier it still
// searches. The starting-ply argument of the public overload puts the root at the boundary.
TEST_F(MinMaxSearchTests, PlyGuardStopsAtMaxPly) {
    auto fen = "r3k2r/p1ppqpb1/bn2pnp1/3PN3/1p2P3/2N2Q1p/PPPBBPPP/R3K2R w KQkq - 0 1"; // Kiwipete
    ChessBoard board;
    ASSERT_TRUE(FFEN::setFEN(fen, board));
    
    for (int ply : {MinMaxSearch::MAX_PLY, MinMaxSearch::MAX_PLY - 1}) {
        MinMaxSearch search;
        search.config.maxDepth = 3;
        TranspositionTable table;
        MinMaxSearch::Variation pv, bv;
        int score = search.alphabeta(board, NEW_HISTORY, table, ply, true, pv, bv);
        if (ply == MinMaxSearch::MAX_PLY) {
            ASSERT_EQ(0, search.visitedNodes);
            ASSERT_EQ(ChessEvaluater::evaluate(board), score);
        } else {
            ASSERT_GT(search.visitedNodes, 0);
        }
    }
    
#ifdef BCHESS_TEST_HOOKS
    // Quiescence at MAX_PLY: Kiwipete has captures, none is visited
    MinMaxSearch search;
    MinMaxSearch::Variation pv;
    int score = search.quiescenceForTest(board, -INT_MAX, INT_MAX, 1, pv, MinMaxSearch::MAX_PLY);
    ASSERT_EQ(0, search.visitedNodes);
    ASSERT_EQ(ChessEvaluater::evaluate(board), score);
    
    MinMaxSearch earlier;
    MinMaxSearch::Variation pv2;
    earlier.quiescenceForTest(board, -INT_MAX, INT_MAX, 1, pv2, MinMaxSearch::MAX_PLY - 1);
    ASSERT_GT(earlier.visitedNodes, 0);
#endif
}

// K+Q v K at a clock of 99: every quiet move reaches 100, which is a draw by the fifty-move rule, and none mates
// in one. The same position at clock 0 is a large win.
TEST_F(MinMaxSearchTests, FiftyMoveRuleDrawsAWin) {
    ChessBoard board;
    ASSERT_TRUE(FFEN::setFEN("8/8/6k1/8/8/8/8/Q3K3 w - - 99 1", board));
    MinMaxSearch search;
    search.config.maxDepth = 2;
    search.config.transpositionTable = false;
    TranspositionTable table;
    MinMaxSearch::Variation pv, bv;
    ASSERT_EQ(0, search.alphabeta(board, NEW_HISTORY, table, 0, true, pv, bv));
    ASSERT_GT(search.pathDraws, 0);
    
    ChessBoard fresh;
    ASSERT_TRUE(FFEN::setFEN("8/8/6k1/8/8/8/8/Q3K3 w - - 0 1", fresh));
    MinMaxSearch other;
    other.config.maxDepth = 2;
    other.config.transpositionTable = false;
    TranspositionTable otherTable;
    MinMaxSearch::Variation pv2, bv2;
    ASSERT_GT(other.alphabeta(fresh, NEW_HISTORY, otherTable, 0, true, pv2, bv2), 500);
    ASSERT_EQ(0, other.pathDraws);
}

// Ra8 mates on the hundredth ply: the mate is not a draw
TEST_F(MinMaxSearchTests, MateOnTheHundredthPlyIsMate) {
    MinMaxSearch::Variation pv;
    ASSERT_EQ(ChessEvaluater::MAT_VALUE - 1, search("6k1/5ppp/8/8/8/8/8/R3K3 w - - 99 1", 2, true, pv));
    ASSERT_EQ("a1a8", FPGN::to_string(pv.moves.bestMove(), FPGN::SANType::uci));
}

// The rules never draw the root: it is searched and returns a move, as a GUI that sends such a position expects
static void expectLegalFirstMove(ChessBoard board, HistoryPtr history) {
    IterativeDeepening deepening;
    deepening.start();
    auto evaluation = deepening.search(board, history, 3, nullptr);
    ASSERT_GT(evaluation.line.count, 0);
    auto legal = ChessMoveGenerator::generateMoves(board);
    bool found = false;
    for (int i = 0; i < legal.count; i++) {
        found = found || legal.moves[i] == evaluation.line.moves[0];
    }
    ASSERT_TRUE(found);
}

TEST_F(MinMaxSearchTests, DrawnRootStillReturnsAMove) {
    // (a) a clock of 100
    ChessBoard board;
    ASSERT_TRUE(FFEN::setFEN("8/8/6k1/8/8/8/8/Q3K3 w - - 100 1", board));
    expectLegalFirstMove(board, NEW_HISTORY);
    
    // (b) a threefold repetition of the start position
    ChessGame game;
    for (int round = 0; round < 2; round++) {
        for (auto m : {"g1f3", "g8f6", "f3g1", "f6g8"}) {
            ASSERT_TRUE(game.move(m)) << m;
        }
    }
    ASSERT_TRUE(ChessEvaluater::isDraw(game.board, game.history));
    expectLegalFirstMove(game.board, game.history);
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
        // (b) a table that holds only P's entry (stored at ply 0), read by a search of Q that starts at ply 1 (the
        // table does not cut off at ply 0): Q has no entry, so P is probed at ply 2 and nowhere else
        {
            TranspositionTable stored;
            MinMaxSearch::Variation pv1;
            ASSERT_EQ(c.sign * (mate - 3), searchWithTable(c.p, 4, true, stored, pv1));
            ChessBoard pBoard;
            ASSERT_TRUE(FFEN::setFEN(c.p, pBoard));
            ASSERT_TRUE(stored.exists(pBoard.getHash()));
            TranspositionEntry entry = stored.get(pBoard.getHash());
            
            auto searchQ = [&](TranspositionTable &t, int64_t &nodes) {
                ChessBoard board;
                EXPECT_TRUE(FFEN::setFEN(c.q, board));
                MinMaxSearch search;
                search.config.maxDepth = 5;
                MinMaxSearch::Variation pv, bv;
                int score = search.alphabeta(board, NEW_HISTORY, t, 1, board.color == WHITE, pv, bv);
                nodes = search.visitedNodes;
                return score;
            };
            TranspositionTable onlyP;
            onlyP.store(entry.depth, entry.hash, entry.value, entry.bestMove, entry.type);
            TranspositionTable empty;
            int64_t withEntry = 0, without = 0;
            ASSERT_EQ(c.sign * (mate - 5), searchQ(empty, without));
            ASSERT_EQ(c.sign * (mate - 5), searchQ(onlyP, withEntry)) << c.q;
            ASSERT_LT(withEntry, without) << "P's entry settled the node at ply 2";
        }
    }
}

// The move that `uci` names among the legal moves of the board
static Move moveNamed(ChessBoard &board, const char *uci) {
    auto moves = ChessMoveGenerator::generateMoves(board);
    for (int i = 0; i < moves.count; i++) {
        if (FPGN::to_string(moves.moves[i], FPGN::SANType::uci) == uci) {
            return moves.moves[i];
        }
    }
    ADD_FAILURE() << uci;
    return INVALID_MOVE;
}

// An entry for the position, stored deep enough for any search of these tests
static void preload(TranspositionTable &table, ChessBoard &board, int value, TranspositionEntryType type = EXACT) {
    auto moves = ChessMoveGenerator::generateMoves(board);
    table.store(10, board.getHash(), value, moves.moves[0], type);
}

static void playMoves(ChessGame &game, std::vector<const char *> moves) {
    for (auto m : moves) {
        ASSERT_TRUE(game.move(m)) << m;
    }
}

// Both Knights go out and back, so that the start position has occurred twice, and then a third time after
// f6g8 when it is Black's turn (Black to move in C below)
static const std::vector<const char *> backAndForth = {"g1f3", "g8f6", "f3g1", "f6g8", "g1f3", "g8f6", "f3g1"};

// The table's value for a position that the history makes a third occurrence is not used: the draw comes first
TEST_F(MinMaxSearchTests, RepetitionBeatsTableEntry) {
    ChessGame game;
    playMoves(game, backAndForth);
    ChessBoard child = game.board;
    child.move(moveNamed(child, "f6g8"));
    
    auto searchRoot = [&](bool preloaded) {
        TranspositionTable table;
        if (preloaded) {
            preload(table, child, -5000); // White to move, and lost: Black would score +5000
        }
        MinMaxSearch search;
        search.config.maxDepth = 2;
        MinMaxSearch::Variation pv, bv;
        return search.alphabeta(game.board, game.history, table, 0, false, pv, bv);
    };
    int fresh = searchRoot(false);
    ASSERT_LT(fresh, 1000);
    ASSERT_EQ(fresh, searchRoot(true));
}

// Kf2+ (a discovered check from the queen) forces Kh2, and a queen move mates, three plies deep: the only mate
// in that depth. The history can plant two earlier copies of the position after Kh2, which makes it a third
// occurrence on that path and turns the mate into a draw.
struct ForcedLine {
    ChessBoard root, afterQueen, afterKing;
    MinMaxSearch::Variation firstMove;
    
    ForcedLine() {
        EXPECT_TRUE(FFEN::setFEN("8/8/8/8/8/8/8/Q3K2k w - - 0 1", root));
        Move check = moveNamed(root, "e1f2");
        afterQueen = root;
        afterQueen.move(check);
        afterKing = afterQueen;
        afterKing.move(moveNamed(afterQueen, "h1h2"));
        firstMove.moves.push(check);
    }
    
    // The history of a game that has been here before: two earlier copies of the position after Kh8, at the
    // parity that makes the one the search reaches the third
    HistoryPtr repeated() {
        auto history = NEW_HISTORY;
        for (BoardHash hash : {afterKing.getHash(), BoardHash(1), afterKing.getHash(), BoardHash(2), root.getHash()}) {
            history->push_back(hash);
        }
        return history;
    }
    
    HistoryPtr clean() {
        auto history = NEW_HISTORY;
        history->push_back(root.getHash());
        return history;
    }
    
    int search(TranspositionTable &table, HistoryPtr history, bool useTable, int64_t *draws = nullptr) {
        MinMaxSearch search;
        search.config.maxDepth = 3;
        search.config.transpositionTable = useTable;
        MinMaxSearch::Variation pv;
        int score = search.alphabeta(root, history, table, 0, true, pv, firstMove);
        if (draws) *draws = search.pathDraws;
        return score;
    }
};

// A subtree that met a repetition has a value that belongs to that path: the table keeps its move, not its value
TEST_F(MinMaxSearchTests, PathDrawIsNotStoredAsValue) {
    ForcedLine line;
    TranspositionTable table;
    int64_t draws = 0;
    line.search(table, line.repeated(), true, &draws);
    ASSERT_GT(draws, 0);
    
    // The position after Kf2+ saw the draw below it
    ASSERT_TRUE(table.exists(line.afterQueen.getHash()));
    ASSERT_EQ(TranspositionEntryType::MOVE_ONLY, table.get(line.afterQueen.getHash()).type);
    ASSERT_TRUE(ChessMoveGenerator::isValid(table.get(line.afterQueen.getHash()).bestMove));
    
    // Another path with no repetition on it reads the same table and finds the mate
    TranspositionTable fresh;
    int mateScore = line.search(fresh, line.clean(), true);
    ASSERT_EQ(mate - 3, mateScore);
    ASSERT_EQ(mateScore, line.search(table, line.clean(), true));
}

// The root is always searched: a table entry for it never ends the search, and the PV is the whole line
TEST_F(MinMaxSearchTests, NoCutoffAtRoot) {
    ChessBoard board;
    ASSERT_TRUE(FFEN::setFEN("r1bqkbnr/pppp1ppp/2n5/4p3/4P3/5N2/PPPP1PPP/RNBQKB1R w KQkq - 2 3", board));
    TranspositionTable table;
    preload(table, board, 5000);
    MinMaxSearch search;
    search.config.maxDepth = 2;
    MinMaxSearch::Variation pv, bv;
    int score = search.alphabeta(board, NEW_HISTORY, table, 0, true, pv, bv);
    ASSERT_LT(score, 1000);
    ASSERT_GT(pv.moves.count, 1);
}

// Black's only move is Kh8, after which White mates. The child of the root is probed with a table that says it
// is lost for White: that is used with a clock of 10, and ignored with a clock of 95 (the 90 guard).
TEST_F(MinMaxSearchTests, NoCutoffNearFiftyMoves) {
    for (int clock : {10, 95}) {
        ChessBoard board;
        ASSERT_TRUE(FFEN::setFEN(("6k1/5Q2/6K1/8/8/8/8/8 b - - " + std::to_string(clock) + " 1").c_str(), board));
        ChessBoard child = board;
        child.move(moveNamed(board, "g8h8"));
        
        TranspositionTable table;
        preload(table, child, -4000);
        MinMaxSearch search;
        search.config.maxDepth = 2;
        MinMaxSearch::Variation pv, bv;
        int score = search.alphabeta(board, NEW_HISTORY, table, 0, false, pv, bv);
        ASSERT_EQ(clock == 10 ? -4000 : mate - 2, score) << clock; // White's score
    }
}

// What the table cannot know: a descendant that already occurred twice on THIS path. A value stored on a path
// without it is reused, and the draw below is never seen. A search that does not read the table sees it. A
// change to this must be deliberate.
TEST_F(MinMaxSearchTests, HiddenRepetitionIsAKnownLimitation) {
    ForcedLine line;
    TranspositionTable table;
    ASSERT_EQ(mate - 3, line.search(table, line.clean(), true));
    
    // The position after Kf2+ is stored with its mate. On the repeated path the table hides the draw below it
    ASSERT_EQ(mate - 3, line.search(table, line.repeated(), true));
    
    // Without the table the draw is seen, and the mate is gone
    TranspositionTable unused;
    ASSERT_LT(line.search(unused, line.repeated(), false), mate - 3);
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
    // Delta pruning depends on alpha, so on the order: plain alpha-beta is the one that the order cannot change
    search.minMaxSearch.config.deltaPruning = false;
    search.minMaxSearch.config.sortMoves = sortMoves;
    search.start();
    search.search(board, NEW_HISTORY, depth, [&](ChessEvaluation e) {
        scores.push_back(e.value);
        nodes.push_back(e.nodes);
    });
}

// Ordering moves only changes how soon alpha-beta cuts off, never the minimax value: with the table never
// read for cut-offs, iterative deepening gives the same score at every depth whatever the order. The depths
// are 2, 2 and 3 rather than the plan's 4: the unsorted full-width search with quiescence at depth 4 takes
// minutes in the Debug test bundle. The bench (depth 6, scripts/bench.sh) checks the same property on nine
// positions, and the plan's gate for the ordering steps is that comparison.
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
    // Recorded before the hash move existed (ENGINE-3 speed step 6): the cumulative nodes of depths 1 to 3.
    // Quiescence in check (ENGINE-3 search step 4) changed them from 95, 1065, 40717.
    ASSERT_EQ((std::vector<int64_t>{107, 1475, 93131}), nodes);
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

#ifdef BCHESS_TEST_HOOKS
// Quiescence alone from the position, with a window of the test's choosing and delta pruning on or off.
// Fills the result, its line and the nodes it visited.
static int quiescenceAt(const char *fen, bool deltaPruning, int alphaOverStandPat, MinMaxSearch::Variation &pv, int64_t &nodes, int &standPatValue, int absoluteAlpha = 0) {
    ChessBoard board;
    EXPECT_TRUE(FFEN::setFEN(fen, board));
    standPatValue = ChessEvaluater::evaluate(board) * (board.color == WHITE ? 1 : -1);
    
    MinMaxSearch search;
    search.config.deltaPruning = deltaPruning;
    int alpha = absoluteAlpha != 0 ? absoluteAlpha : standPatValue + alphaOverStandPat;
    int score = search.quiescenceForTest(board, alpha, INT_MAX, board.color == WHITE ? 1 : -1, pv);
    nodes = search.visitedNodes;
    return score;
}

// A capture that can lift the score above alpha is never pruned
TEST_F(MinMaxSearchTests, DeltaPruningKeepsAWinningCapture) {
    auto fen = "k7/3r4/8/8/3Q4/8/8/K7 w - - 0 1"; // Qxd7 wins a rook for nothing
    MinMaxSearch::Variation pruned, plain;
    int64_t prunedNodes, plainNodes;
    int standPat, standPat2;
    int withDelta = quiescenceAt(fen, true, 300, pruned, prunedNodes, standPat);
    int without = quiescenceAt(fen, false, 300, plain, plainNodes, standPat2);
    ASSERT_GT(withDelta, standPat + 300);
    ASSERT_EQ(without, withDelta);
    ASSERT_EQ(plainNodes, prunedNodes);
}

// A pawn capture that is hopeless against alpha is skipped: fewer nodes, and the node still fails low
TEST_F(MinMaxSearchTests, DeltaPruningSkipsHopelessCapture) {
    auto fen = "k7/8/8/3p4/4P3/8/8/K7 w - - 0 1"; // exd5 wins a pawn
    MinMaxSearch::Variation pruned, plain;
    int64_t prunedNodes, plainNodes;
    int standPat, standPat2;
    int withDelta = quiescenceAt(fen, true, 1000, pruned, prunedNodes, standPat);
    int without = quiescenceAt(fen, false, 1000, plain, plainNodes, standPat2);
    ASSERT_EQ(0, prunedNodes);
    ASSERT_GT(plainNodes, 0);
    ASSERT_LE(withDelta, standPat + 1000);
    ASSERT_LE(without, standPat + 1000);
    ASSERT_EQ(standPat, withDelta);
}

// A capture that promotes can lift the score by a queen, whatever the piece it takes: it is never pruned. Here
// gxh8 takes a rook (500 + 200 below alpha, so a plain capture would go) and does not give check.
TEST_F(MinMaxSearchTests, DeltaPruningKeepsAPromotion) {
    auto fen = "7r/6P1/8/8/8/8/2k5/7K w - - 0 1";
    MinMaxSearch::Variation pruned, plain;
    int64_t prunedNodes, plainNodes;
    int standPat, standPat2;
    int withDelta = quiescenceAt(fen, true, 1000, pruned, prunedNodes, standPat);
    int without = quiescenceAt(fen, false, 1000, plain, plainNodes, standPat2);
    ASSERT_GT(prunedNodes, 0);
    ASSERT_EQ(plainNodes, prunedNodes);
    ASSERT_EQ(without, withDelta);
}

// While alpha is a mate score the margin means nothing: the node is not pruned, whatever the capture
TEST_F(MinMaxSearchTests, DeltaPruningStopsAtAMateScoreAlpha) {
    auto fen = "k7/8/8/3p4/4P3/8/8/K7 w - - 0 1"; // exd5 wins a pawn
    MinMaxSearch::Variation pv;
    int64_t nodes;
    int standPat;
    quiescenceAt(fen, true, 0, pv, nodes, standPat, ChessEvaluater::MAT_VALUE - 5);
    ASSERT_GT(nodes, 0);
}

// 1. fxg7 is mate with a pawn that takes a knight: it wins little, but it ends the game, so a node that is far
// below alpha still searches it
TEST_F(MinMaxSearchTests, DeltaPruningKeepsAMatingCapture) {
    auto fen = "7k/6np/5P2/4B3/2B5/8/8/6K1 w - - 0 1"; // Stockfish: mate in 1, fxg7
    MinMaxSearch::Variation pv;
    int64_t nodes;
    int standPat;
    int score = quiescenceAt(fen, true, 1000, pv, nodes, standPat);
    ASSERT_EQ(ChessEvaluater::MAT_VALUE - 1, score);
    ASSERT_EQ("f6g7", FPGN::to_string(pv.moves.bestMove(), FPGN::SANType::uci));
    
    // The search at maxDepth 0 is quiescence alone, and finds it too
    ChessBoard board;
    ASSERT_TRUE(FFEN::setFEN(fen, board));
    MinMaxSearch search;
    search.config.maxDepth = 0;
    TranspositionTable table;
    MinMaxSearch::Variation rootPV, bv;
    ASSERT_EQ(ChessEvaluater::MAT_VALUE - 1, search.alphabeta(board, NEW_HISTORY, table, 0, true, rootPV, bv));
    ASSERT_EQ("f6g7", FPGN::to_string(rootPV.moves.bestMove(), FPGN::SANType::uci));
}
// 1... Nf3+ forks the king and the queen. In check, White cannot decline to move: every evasion loses the queen
// to Nxh2, and the stand-pat that counts the queen as White's must not be the answer. (The pawns keep the ending
// live: K+N v K is a dead position, worth 0.)
TEST_F(MinMaxSearchTests, QuiescenceDoesNotStandPatInCheck) {
    ChessBoard board;
    ASSERT_TRUE(FFEN::setFEN("4k3/p7/8/8/8/5n2/P6Q/4K3 w - - 0 1", board));
    ASSERT_TRUE(board.isCheck(WHITE));
    int standPat = ChessEvaluater::evaluate(board);
    
    MinMaxSearch search;
    MinMaxSearch::Variation pv;
    int score = search.quiescenceForTest(board, -INT_MAX, INT_MAX, 1, pv);
    ASSERT_LE(score, standPat - (ChessEvaluater::pieceValue(QUEEN) - ChessEvaluater::pieceValue(KNIGHT)));
    ASSERT_GT(pv.moves.count, 0);
}

// Re8+ checks the king and every evasion is quiet, so each one reaches a clock of 100 at once. The clock is
// not in the hash and a quiescence line can run past it: the draw comes from inside quiescence, loaded from
// a FEN (reversiblePlies -1).
TEST_F(MinMaxSearchTests, QuiescenceSeesFiftyMoveDraw) {
    ChessBoard board;
    ASSERT_TRUE(FFEN::setFEN("4r3/7k/8/8/8/8/8/Q3K3 w - - 99 1", board));
    ASSERT_TRUE(board.isCheck(WHITE));
    ASSERT_EQ(-1, board.reversiblePlies);
    auto evasions = ChessMoveGenerator::generateMoves(board);
    
    MinMaxSearch search;
    MinMaxSearch::Variation pv;
    ASSERT_EQ(0, search.quiescenceForTest(board, -INT_MAX, INT_MAX, 1, pv));
    ASSERT_EQ(evasions.count, search.pathDraws);
    
    // The same position at clock 0 is not a draw: White keeps its queen against the rook
    ChessBoard fresh;
    ASSERT_TRUE(FFEN::setFEN("4r3/7k/8/8/8/8/8/Q3K3 w - - 0 1", fresh));
    MinMaxSearch other;
    MinMaxSearch::Variation pv2;
    ASSERT_NE(0, other.quiescenceForTest(fresh, -INT_MAX, INT_MAX, 1, pv2));
    ASSERT_EQ(0, other.pathDraws);
}

// The history holds every evasion's position twice, at the parity that makes the evasion a third occurrence
TEST_F(MinMaxSearchTests, QuiescenceSeesRepetition) {
    ChessBoard board;
    ASSERT_TRUE(FFEN::setFEN("4r3/7k/8/8/8/8/8/Q3K3 w - - 0 1", board));
    auto evasions = ChessMoveGenerator::generateMoves(board);
    ASSERT_GT(evasions.count, 1);
    
    auto history = NEW_HISTORY;
    for (int i = 0; i < 4 * evasions.count; i++) {
        history->push_back(BoardHash(1000 + i)); // the entries between are never the node's position
    }
    history->push_back(board.getHash());
    for (int i = 0; i < evasions.count; i++) {
        ChessBoard child = board;
        child.move(evasions.moves[i]);
        history->at(history->size() - 2 - 4 * i) = child.getHash();
        history->at(history->size() - 4 - 4 * i) = child.getHash();
    }
    
    // A game played from the start knows how far back a repetition can reach (reversiblePlies); a FEN does not
    for (int reversible : {int(history->size()) - 1, -1}) {
        board.reversiblePlies = reversible;
        MinMaxSearch search;
        MinMaxSearch::Variation pv;
        ASSERT_EQ(0, search.quiescenceForTest(board, -INT_MAX, INT_MAX, 1, pv, 0, history)) << reversible;
        ASSERT_EQ(evasions.count, search.pathDraws) << reversible;
    }
    
    // Without the planted copies the evasions are not draws
    MinMaxSearch search;
    MinMaxSearch::Variation pv;
    ASSERT_NE(0, search.quiescenceForTest(board, -INT_MAX, INT_MAX, 1, pv, 0, NEW_HISTORY));
}

// Ra8 mates: in check with no evasion, quiescence scores the mate at its own ply
TEST_F(MinMaxSearchTests, QuiescenceMateInCheck) {
    ChessBoard board;
    ASSERT_TRUE(FFEN::setFEN("R5k1/5ppp/8/8/8/8/8/4K3 b - - 0 1", board));
    ASSERT_TRUE(board.isCheck(BLACK));
    MinMaxSearch search;
    MinMaxSearch::Variation pv;
    ASSERT_EQ(-(mate - 3), search.quiescenceForTest(board, -INT_MAX, INT_MAX, -1, pv, 3));
}
#endif
