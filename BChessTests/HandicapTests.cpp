//
//  HandicapTests.cpp
//  BChessTests
//
//  The strength levels below full strength (APP-3): the choice among the root moves, and the handicapped search.
//

#include <gtest/gtest.h>

#include <memory>
#include <set>
#include <string>

#include "ChessEngine.hpp"
#include "FFEN.hpp"
#include "FPGN.hpp"

class HandicapTests: public ::testing::Test {
public:
    void SetUp() {
        ChessEngine::initialize();
    }
};

static const Strength levels[] = {Strength::beginner, Strength::casual, Strength::club, Strength::strong};
static const int MAT = ChessEvaluater::MAT_VALUE;

static std::string uci(Move move) {
    return FPGN::to_string(move, FPGN::SANType::uci);
}

static HistoryPtr copyOf(ChessEngine &engine) {
    return std::make_shared<std::vector<BoardHash>>(*engine.game().history);
}

// One search of the engine's current position at a strength, as the bridge runs it
static ChessEvaluation run(ChessEngine &engine, Strength strength, int depth = 4, int *callbacks = nullptr) {
    ChessEvaluation result;
    engine.iterativeSearch.start();
    engine.searchBestMove(engine.game().board, copyOf(engine), depth, true, strength, [&](ChessEvaluation info, bool done) {
        if (done) {
            result = info;
            if (callbacks) (*callbacks)++;
        }
    });
    return result;
}

static std::unique_ptr<ChessEngine> makeEngine(const char *fen) {
    auto engine = std::make_unique<ChessEngine>(1);
    EXPECT_TRUE(engine->setFEN(fen));
    return engine;
}

static const char *middlegame = "r1bqkbnr/pppp1ppp/2n5/4p3/4P3/5N2/PPPP1PPP/RNBQKB1R w KQkq - 2 3";

TEST_F(HandicapTests, ChooseNeverPlaysOutsideTheWindow) {
    std::vector<int> scores = {100, 90, -300};
    for (int step = 0; step < 1000; step++) {
        ASSERT_NE(2, chooseRootMove(scores, 25, step / 1000.0)) << step;
    }
}

TEST_F(HandicapTests, ChooseSpreadsEqualMoves) {
    std::vector<int> scores = {0, 0, 0};
    std::set<int> seen;
    for (int step = 0; step < 1000; step++) {
        seen.insert(chooseRootMove(scores, 25, step / 1000.0));
    }
    ASSERT_EQ(3u, seen.size());
}

TEST_F(HandicapTests, ChooseIsDeterministic) {
    std::vector<int> scores = {40, 35, 20, 0};
    for (double u : {0.0, 0.3, 0.77, 0.999}) {
        ASSERT_EQ(chooseRootMove(scores, 25, u), chooseRootMove(scores, 25, u));
    }
}

// The weight is exp((score - best) / temperature): the boundary between the moves is where u reaches the first
// move's share of the total, so equal weights (a boundary at 0.5) would fail
TEST_F(HandicapTests, ChooseWeightsMovesExponentially) {
    // {0, -T}: the weights are 1 and e^-1, so the boundary is 1 / (1 + e^-1)
    double first = 1.0 / (1.0 + std::exp(-1.0));
    ASSERT_NEAR(0.7311, first, 0.0001);
    for (int temperature : {25, 60}) {
        std::vector<int> scores = {0, -temperature};
        ASSERT_EQ(0, chooseRootMove(scores, temperature, first - 0.005)) << temperature;
        ASSERT_EQ(1, chooseRootMove(scores, temperature, first + 0.005)) << temperature;
        // The order of the scores does not matter, only their differences
        std::vector<int> reversed = {-temperature, 0};
        ASSERT_EQ(0, chooseRootMove(reversed, temperature, (1 - first) - 0.005)) << temperature;
        ASSERT_EQ(1, chooseRootMove(reversed, temperature, (1 - first) + 0.005)) << temperature;
    }
    // Half a temperature below: weights 1 and e^-0.5
    double half = 1.0 / (1.0 + std::exp(-0.5));
    std::vector<int> scores = {0, -30};
    ASSERT_EQ(0, chooseRootMove(scores, 60, half - 0.005));
    ASSERT_EQ(1, chooseRootMove(scores, 60, half + 0.005));
}

TEST_F(HandicapTests, AFoundMateIsAlwaysPlayed) {
    std::vector<int> scores = {MAT - 1, MAT - 3, 1200};
    scores.insert(scores.end(), 20, 0);
    for (auto level : levels) {
        int temperature = Handicap::of(level).temperature;
        for (int step = 0; step < 1000; step++) {
            int index = chooseRootMove(scores, temperature, step / 1000.0);
            ASSERT_TRUE(index == 0 || index == 1) << index;
        }
    }
}

TEST_F(HandicapTests, AForcedLossIsNeverChosen) {
    std::vector<int> scores = {-MAT + 2, -1200};
    for (auto level : levels) {
        int temperature = Handicap::of(level).temperature;
        for (int step = 0; step < 1000; step++) {
            ASSERT_EQ(1, chooseRootMove(scores, temperature, step / 1000.0));
        }
    }
}

TEST_F(HandicapTests, ALargeAdvantageKeepsItsOrder) {
    std::vector<int> scores = {1200, 300};
    for (auto level : {Strength::club, Strength::strong}) {
        int temperature = Handicap::of(level).temperature;
        for (int step = 0; step < 1000; step++) {
            ASSERT_EQ(0, chooseRootMove(scores, temperature, step / 1000.0));
        }
    }
}

TEST_F(HandicapTests, ClubTakesAHangingQueen) {
    for (uint64_t seed = 1; seed <= 20; seed++) {
        auto engineHolder = makeEngine("4k3/8/8/3q4/8/8/8/3RK3 w - - 0 1"); auto &engine = *engineHolder;
        engine.seedRandom(seed);
        auto result = run(engine, Strength::club);
        ASSERT_EQ("d1d5", uci(result.line.bestMove())) << seed;
    }
}

TEST_F(HandicapTests, BlindnessPlaysTheCaptureQuiescenceRefuses) {
    // The knight takes a pawn that the other pawn defends: a quiescence search sees the recapture
    const char *fen = "4k3/8/4p3/3p4/8/4N3/8/4K3 w - - 0 1";
    int blindCaptures = 0, seeingCaptures = 0;
    for (uint64_t seed = 1; seed <= 20; seed++) {
        for (double blindness : {1.0, 0.0}) {
            ChessEngine engine(1);
            ASSERT_TRUE(engine.setFEN(fen));
            std::mt19937_64 random(seed);
            engine.iterativeSearch.start();
            auto result = HandicappedSearch::search(engine.iterativeSearch, engine.game().board, copyOf(engine), Handicap{1, 1, blindness}, random);
            bool capture = uci(result.line.bestMove()) == "e3d5";
            (blindness == 1.0 ? blindCaptures : seeingCaptures) += capture ? 1 : 0;
        }
    }
    ASSERT_EQ(20, blindCaptures);
    ASSERT_EQ(0, seeingCaptures);
}

TEST_F(HandicapTests, CasualVariesFromTheStart) {
    std::set<std::string> moves;
    for (uint64_t seed = 1; seed <= 10; seed++) {
        ChessEngine engine(1);
        engine.seedRandom(seed);
        moves.insert(uci(run(engine, Strength::casual).line.bestMove()));
    }
    ASSERT_GE(moves.size(), 2u);
}

// Three times the same position after the queen's move: the move that makes the third is a draw
static void shuffle(ChessEngine &engine) {
    for (auto move : {"a1a2", "e8d8", "a2a1", "d8e8", "a1a2", "e8d8", "a2a1", "d8e8"}) {
        ASSERT_TRUE(engine.move(std::string(move))) << move;
    }
}

TEST_F(HandicapTests, ARepeatingMoveScoresADraw) {
    ChessEngine engine(1);
    ASSERT_TRUE(engine.setFEN("4k3/8/8/8/8/8/8/Q3K3 w - - 0 1"));
    shuffle(engine);
    
    auto repeated = HandicappedSearch::scoreRootMoves(engine.iterativeSearch, engine.game().board, copyOf(engine), 0, true);
    int zeroes = 0;
    for (auto &entry : repeated) {
        if (uci(entry.move) == "a1a2") {
            ASSERT_EQ(0, entry.score);
            zeroes++;
        } else if (uci(entry.move) == "a1b1") {
            ASSERT_GT(entry.score, 500);
        }
    }
    ASSERT_EQ(1, zeroes);
    
    // Without the history the same move is worth a queen
    ChessEngine fresh(1);
    ASSERT_TRUE(fresh.setFEN("4k3/8/8/8/8/8/8/Q3K3 w - - 0 1"));
    for (auto &entry : HandicappedSearch::scoreRootMoves(fresh.iterativeSearch, fresh.game().board, copyOf(fresh), 0, true)) {
        if (uci(entry.move) == "a1a2") {
            ASSERT_GT(entry.score, 500);
        }
    }
}

TEST_F(HandicapTests, BlackChoosesBlacksBest) {
    for (uint64_t seed = 1; seed <= 20; seed++) {
        auto engineHolder = makeEngine("3rk3/8/8/8/3Q4/8/8/4K3 b - - 0 1"); auto &engine = *engineHolder;
        engine.seedRandom(seed);
        auto result = run(engine, Strength::club);
        ASSERT_EQ("d8d4", uci(result.line.bestMove())) << seed;
        ASSERT_LT(result.value, 0) << seed;
    }
}

TEST_F(HandicapTests, NoMoveAtCheckmateOrStalemate) {
    for (auto fen : {"7k/6Q1/6K1/8/8/8/8/8 b - - 0 1", "7k/5Q2/6K1/8/8/8/8/8 b - - 0 1"}) {
        auto engineHolder = makeEngine(fen); auto &engine = *engineHolder;
        for (auto level : levels) {
            int callbacks = 0;
            auto result = run(engine, level, 4, &callbacks);
            ASSERT_EQ(0, result.line.count) << fen;
            ASSERT_EQ(1, callbacks) << fen;
        }
    }
}

TEST_F(HandicapTests, ARuleDrawnRootStillPlays) {
    auto clockHolder = makeEngine("4k3/8/8/8/8/8/8/Q3K3 w - - 100 80"); auto &clock = *clockHolder;
    ASSERT_GT(run(clock, Strength::club).line.count, 0);
    
    ChessEngine repeated(1);
    ASSERT_TRUE(repeated.setFEN("4k3/8/8/8/8/8/8/Q3K3 w - - 0 1"));
    shuffle(repeated);
    ASSERT_TRUE(ChessEvaluater::isDraw(repeated.game().board, repeated.game().history));
    ASSERT_GT(run(repeated, Strength::club).line.count, 0);
}

TEST_F(HandicapTests, DeepEntriesDoNotLiftTheCap) {
    auto freshHolder = makeEngine(middlegame); auto &fresh = *freshHolder;
    fresh.seedRandom(7);
    auto expected = run(fresh, Strength::club);
    
    auto usedHolder = makeEngine(middlegame); auto &used = *usedHolder;
    run(used, Strength::maximum, 6);
    used.seedRandom(7);
    auto actual = run(used, Strength::club);
    
    ASSERT_EQ(expected.line.bestMove(), actual.line.bestMove());
    ASSERT_EQ(expected.value, actual.value);
    ASSERT_EQ(expected.nodes, actual.nodes);
}

TEST_F(HandicapTests, BlindValuesDoNotReachMaximum) {
    auto freshHolder = makeEngine(middlegame); auto &fresh = *freshHolder;
    auto expected = run(fresh, Strength::maximum, 5);
    
    auto usedHolder = makeEngine(middlegame); auto &used = *usedHolder;
    std::mt19937_64 random(3);
    used.iterativeSearch.start();
    HandicappedSearch::search(used.iterativeSearch, used.game().board, copyOf(used), Handicap{2, 60, 1.0}, random);
    auto actual = run(used, Strength::maximum, 5);
    
    ASSERT_EQ(expected.line.bestMove(), actual.line.bestMove());
    ASSERT_EQ(expected.value, actual.value);
    ASSERT_EQ(expected.nodes, actual.nodes);
}

TEST_F(HandicapTests, ResultIsShapedLikeTheSearch) {
    ChessEngine engine(1);
    engine.seedRandom(5);
    auto result = run(engine, Strength::beginner);
    ASSERT_GT(result.line.count, 0);
    ASSERT_EQ(Handicap::of(Strength::beginner).depth, result.depth);
    ASSERT_GE(result.nodes, 20);
    ASSERT_GE(result.selDepth, 1);
    ASSERT_EQ(WHITE, result.engineColor);
    
    // The first move is legal, and is the one the line starts with
    auto moves = ChessMoveGenerator::generateMoves(engine.game().board);
    bool legal = false;
    for (int index = 0; index < moves.count; index++) {
        legal = legal || moves.moves[index] == result.line.bestMove();
    }
    ASSERT_TRUE(legal);
    
    // From White's point of view, whoever moves: Black to move with a free queen to take
    auto blackHolder = makeEngine("3rk3/8/8/8/3Q4/8/8/4K3 b - - 0 1"); auto &black = *blackHolder;
    ASSERT_LT(run(black, Strength::casual).value, 0);
}

TEST_F(HandicapTests, QuiescenceFollowsForcingLinesPastTheCap) {
    // Rxe8+ Qxe8 Qxe8#: two captures with check after the first move, which a depth of 1 does not reach
    // without quiescence
    auto engineHolder = makeEngine("3qr1k1/5ppp/8/8/Q7/8/8/4R1K1 w - - 0 1"); auto &engine = *engineHolder;
    for (bool quiescence : {true, false}) {
        auto scored = HandicappedSearch::scoreRootMoves(engine.iterativeSearch, engine.game().board, copyOf(engine), 0, quiescence);
        bool found = false;
        for (auto &entry : scored) {
            if (uci(entry.move) == "e1e8") {
                found = true;
                ASSERT_EQ(quiescence, ChessEvaluater::isMateScore(entry.score)) << entry.score;
            }
        }
        ASSERT_TRUE(found);
    }
}

TEST_F(HandicapTests, MaximumIsTheIterativeSearch) {
    auto viaEngineHolder = makeEngine(middlegame); auto &viaEngine = *viaEngineHolder;
    auto result = run(viaEngine, Strength::maximum, 4);
    
    auto directHolder = makeEngine(middlegame); auto &direct = *directHolder;
    direct.iterativeSearch.start();
    auto expected = direct.iterativeSearch.search(direct.game().board, copyOf(direct), 4, nullptr);
    
    ASSERT_EQ(expected.line.bestMove(), result.line.bestMove());
    ASSERT_EQ(expected.value, result.value);
}

// The root loop checks for a cancel after each child: a cancel during the first child ends the loop there
TEST_F(HandicapTests, CancelEndsTheRootLoop) {
    ChessEngine engine(1);
    engine.iterativeSearch.start();
    engine.iterativeSearch.minMaxSearch.checkpoint = [&] { engine.iterativeSearch.cancel(); };
    auto scored = HandicappedSearch::scoreRootMoves(engine.iterativeSearch, engine.game().board, copyOf(engine), 2, true);
    engine.iterativeSearch.minMaxSearch.checkpoint = nullptr;
    ASSERT_TRUE(scored.empty());
    ASSERT_TRUE(engine.iterativeSearch.cancelled());
}
