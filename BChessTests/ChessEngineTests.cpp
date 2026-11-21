//
//  ChessEngineTests.cpp
//  BChessTests
//

#include <gtest/gtest.h>

#include "ChessEngine.hpp"

class ChessEngineTests: public ::testing::Test {
public:
    void SetUp() {
        ChessEngine::initialize();
    }
};

TEST_F(ChessEngineTests, CanPlayFromEarlierPositionOfFinishedGame) {
    ChessEngine engine;
    ASSERT_TRUE(engine.setPGN("1. f3 e5 2. g4 Qh4# 0-1"));
    
    // Checkmate: nothing to play at the end
    ASSERT_FALSE(engine.canPlay());
    
    // One step back, Black can still play a move, which starts a variation
    engine.game().moveTo(ChessGame::Direction::backward, 0);
    ASSERT_TRUE(engine.canPlay());
    
    // A resigned game: moves exist, but the result is declared
    ASSERT_TRUE(engine.setPGN("1. e4 1-0"));
    ASSERT_FALSE(engine.canPlay());
    engine.game().moveTo(ChessGame::Direction::backward, 0);
    ASSERT_TRUE(engine.canPlay());
    
    ASSERT_TRUE(engine.setPGN("1. e4 e5 *"));
    ASSERT_TRUE(engine.canPlay());
}

TEST_F(ChessEngineTests, FailedLoadAllGamesKeepsGames) {
    ChessEngine engine;
    ASSERT_TRUE(engine.loadAllGames("1. e4 e5 *"));
    auto pgn = engine.getPGN(false);
    
    ASSERT_FALSE(engine.loadAllGames("this is not a game"));
    ASSERT_EQ(pgn, engine.getPGN(false));
    
    ASSERT_FALSE(engine.loadAllGames(""));
    ASSERT_EQ(pgn, engine.getPGN(false));
    
    ASSERT_FALSE(engine.loadAllGames("  \n"));
    ASSERT_EQ(pgn, engine.getPGN(false));
    
    ASSERT_EQ(1u, engine.games.size());
    ASSERT_EQ(2, engine.game().getNumberOfMoves());
}

TEST_F(ChessEngineTests, LoadAllGamesResetsGameIndex) {
    ChessEngine engine;
    ASSERT_TRUE(engine.loadAllGames("[Title \"a\"] 1. e4 e5 [Title \"b\"] 1. d4 d5"));
    ASSERT_EQ(2u, engine.games.size());
    engine.gameIndex = 1;
    ASSERT_TRUE(engine.loadAllGames("1. c4 *"));
    ASSERT_EQ(0u, engine.gameIndex);
    ASSERT_EQ(1u, engine.games.size());
}

// The openings are lines from the standard start position, so a game that started from another
// position must not be offered a book move, even when its moves spell a book line.
TEST_F(ChessEngineTests, NoBookMoveFromAFENGame) {
    ChessEngine engine;
    ASSERT_TRUE(engine.loadOpening("1. e4 e5 2. Nf3 *"));
    
    // From the start position the book answers 1. e4 with e5
    ASSERT_TRUE(engine.game().move("e2e4"));
    ChessEvaluation fromStart;
    ASSERT_TRUE(engine.lookupOpeningMove(fromStart));
    
    // From a FEN where e2-e4 is also legal, there is no book move
    ASSERT_TRUE(engine.setFEN("4k3/8/8/8/8/8/4P3/4K3 w - - 0 1"));
    ASSERT_TRUE(engine.game().move("e2e4"));
    ChessEvaluation fromFEN;
    ASSERT_FALSE(engine.lookupOpeningMove(fromFEN));
}

// A position that occurred three times is drawn: nothing can be played from it, even in the middle of a
// game that has a declared result.
TEST_F(ChessEngineTests, CannotPlayFromARepeatedPosition) {
    ChessEngine engine;
    ASSERT_TRUE(engine.setPGN("1. Nf3 Nf6 2. Ng1 Ng8 3. Nf3 Nf6 4. Ng1 Ng8 5. Nf3 Nf6 1/2-1/2"));
    engine.game().moveTo(ChessGame::Direction::backward, 0);
    ASSERT_FALSE(engine.canPlay());
    
    // Two plies earlier the position occurred only twice
    engine.game().moveTo(ChessGame::Direction::backward, 0);
    engine.game().moveTo(ChessGame::Direction::backward, 0);
    ASSERT_TRUE(engine.canPlay());
}

// The initial position counts as the first occurrence: after both knights went out and back twice, the
// start position has occurred three times.
TEST_F(ChessEngineTests, CannotPlayFromTheRepeatedStartPosition) {
    ChessEngine engine;
    ASSERT_TRUE(engine.setPGN("1. Nf3 Nf6 2. Ng1 Ng8 3. Nf3 Nf6 4. Ng1 Ng8 *"));
    ASSERT_FALSE(engine.canPlay());
    
    ASSERT_TRUE(engine.setPGN("1. Nf3 Nf6 2. Ng1 Ng8 3. Nf3 Nf6 4. Ng1 *"));
    ASSERT_TRUE(engine.canPlay());
}

// The reason nothing can be played, for the status line.
TEST_F(ChessEngineTests, GameEndCheckmate) {
    ChessEngine engine;
    ASSERT_TRUE(engine.setPGN("1. f3 e5 2. g4 Qh4#"));
    ASSERT_EQ(ChessEngine::GameEnd::checkmate, engine.gameEnd());
    
    engine.game().moveTo(ChessGame::Direction::backward, 0);
    ASSERT_EQ(ChessEngine::GameEnd::none, engine.gameEnd());
}

TEST_F(ChessEngineTests, GameEndStalemate) {
    ChessEngine engine;
    ASSERT_TRUE(engine.setFEN("7k/5Q2/6K1/8/8/8/8/8 b - - 0 1"));
    ASSERT_EQ(ChessEngine::GameEnd::stalemate, engine.gameEnd());
}

TEST_F(ChessEngineTests, GameEndRepetition) {
    ChessEngine engine;
    ASSERT_TRUE(engine.setPGN("1. Nf3 Nf6 2. Ng1 Ng8 3. Nf3 Nf6 4. Ng1 Ng8 5. Nf3 Nf6 1/2-1/2"));
    engine.game().moveTo(ChessGame::Direction::backward, 0);
    ASSERT_EQ(ChessEngine::GameEnd::repetition, engine.gameEnd());
}

TEST_F(ChessEngineTests, GameEndFiftyMoves) {
    ChessEngine engine;
    ASSERT_TRUE(engine.setFEN("4k3/8/8/8/8/8/R7/4K3 w - - 99 80"));
    ASSERT_EQ(ChessEngine::GameEnd::none, engine.gameEnd());
    ASSERT_TRUE(engine.game().move("a2a3"));
    ASSERT_EQ(ChessEngine::GameEnd::fiftyMoves, engine.gameEnd());
    ASSERT_FALSE(engine.canPlay());
}

TEST_F(ChessEngineTests, GameEndDeadPosition) {
    ChessEngine engine;
    // Knight against knight is not dead; after the capture, a lone knight cannot mate
    ASSERT_TRUE(engine.setFEN("4k3/8/8/3n4/8/2N5/8/4K3 w - - 0 1"));
    ASSERT_EQ(ChessEngine::GameEnd::none, engine.gameEnd());
    ASSERT_TRUE(engine.game().move("c3d5"));
    ASSERT_EQ(ChessEngine::GameEnd::deadPosition, engine.gameEnd());
    ASSERT_FALSE(engine.canPlay());
}

TEST_F(ChessEngineTests, LineResultAtTheEnd) {
    ChessEngine e1;
    ASSERT_TRUE(e1.setPGN("1. f3 e5 2. g4 Qh4#"));
    auto result = e1.lineResult();
    ASSERT_EQ(ChessEngine::GameEnd::checkmate, result.end);
    ASSERT_EQ(ChessGame::Outcome::black_wins, result.outcome);
    
    ChessEngine e2;
    ASSERT_TRUE(e2.setPGN("1. e4 e5 2. Bc4 Nc6 3. Qh5 Nf6 4. Qxf7# *"));
    result = e2.lineResult();
    ASSERT_EQ(ChessEngine::GameEnd::checkmate, result.end);
    ASSERT_EQ(ChessGame::Outcome::white_wins, result.outcome);
    
    ChessEngine e3;
    ASSERT_TRUE(e3.setFEN("7k/5Q2/6K1/8/8/8/8/8 b - - 0 1"));
    result = e3.lineResult();
    ASSERT_EQ(ChessEngine::GameEnd::stalemate, result.end);
    ASSERT_EQ(ChessGame::Outcome::draw, result.outcome);
    
    ChessEngine e4;
    ASSERT_TRUE(e4.setPGN("1. e4 e5 0-1"));
    result = e4.lineResult();
    ASSERT_EQ(ChessEngine::GameEnd::finished, result.end);
    ASSERT_EQ(ChessGame::Outcome::black_wins, result.outcome);
    
    ChessEngine e5;
    ASSERT_TRUE(e5.setPGN("1. e4 e5 *"));
    result = e5.lineResult();
    ASSERT_EQ(ChessEngine::GameEnd::none, result.end);
    ASSERT_EQ(ChessGame::Outcome::in_progress, result.outcome);
}

TEST_F(ChessEngineTests, LineResultWhileBrowsing) {
    ChessEngine engine;
    ASSERT_TRUE(engine.setPGN("1. f3 e5 2. g4 Qh4#"));
    engine.game().moveTo(ChessGame::Direction::backward, 0);
    ASSERT_EQ(ChessEngine::GameEnd::none, engine.gameEnd());
    auto result = engine.lineResult();
    ASSERT_EQ(ChessEngine::GameEnd::checkmate, result.end);
    ASSERT_EQ(ChessGame::Outcome::black_wins, result.outcome);
    // Reading the result leaves the cursor where it was
    ASSERT_EQ(3, engine.game().getNumberOfMoves());
    ASSERT_EQ(ChessEngine::GameEnd::none, engine.gameEnd());
    
    engine.game().moveTo(ChessGame::Direction::start, 0);
    ASSERT_EQ(ChessEngine::GameEnd::checkmate, engine.lineResult().end);
    ASSERT_EQ(0, engine.game().getNumberOfMoves());
}

// Reading the result of a line browsed from its end must not touch the live game's repetition history
TEST_F(ChessEngineTests, LineResultKeepsTheLiveHistory) {
    ChessEngine engine;
    ASSERT_TRUE(engine.setPGN("1. Nf3 Nf6 2. Ng1 Ng8 3. Nf3 Nf6 4. Ng1 Ng8 5. Nf3 Nf6 1/2-1/2"));
    engine.game().moveTo(ChessGame::Direction::backward, 0);
    ASSERT_EQ(ChessEngine::GameEnd::repetition, engine.gameEnd());
    
    auto live = engine.game().history;
    auto before = *live;
    ASSERT_FALSE(before.empty());
    auto result = engine.lineResult();
    ASSERT_EQ(ChessEngine::GameEnd::repetition, result.end);
    ASSERT_EQ(ChessGame::Outcome::draw, result.outcome);
    ASSERT_EQ(live, engine.game().history);
    ASSERT_EQ(before, *engine.game().history);
    ASSERT_EQ(ChessEngine::GameEnd::repetition, engine.gameEnd());
}

TEST_F(ChessEngineTests, GameEndDeclaredResult) {
    ChessEngine engine;
    ASSERT_TRUE(engine.setPGN("1. e4 1-0"));
    ASSERT_EQ(ChessEngine::GameEnd::finished, engine.gameEnd());
    
    engine.game().moveTo(ChessGame::Direction::backward, 0);
    ASSERT_EQ(ChessEngine::GameEnd::none, engine.gameEnd());
}

TEST_F(ChessEngineTests, CanPlayMatchesGameEnd) {
    ChessEngine engine;
    for (auto pgn : {"1. f3 e5 2. g4 Qh4#", "1. e4 1-0", "1. e4 e5 *",
                     "1. Nf3 Nf6 2. Ng1 Ng8 3. Nf3 Nf6 4. Ng1 Ng8 5. Nf3 Nf6 1/2-1/2"}) {
        ASSERT_TRUE(engine.setPGN(pgn));
        // Every position of the line, from the end back to the start
        do {
            ASSERT_EQ(engine.canPlay(), engine.gameEnd() == ChessEngine::GameEnd::none) << pgn;
        } while (engine.game().canMoveTo(ChessGame::Direction::backward) &&
                 (engine.game().moveTo(ChessGame::Direction::backward, 0), true));
    }
    ASSERT_TRUE(engine.setFEN("7k/5Q2/6K1/8/8/8/8/8 b - - 0 1"));
    ASSERT_EQ(engine.canPlay(), engine.gameEnd() == ChessEngine::GameEnd::none);
}

// Castling rights are part of a position (FIDE 9.2): the start arrangement occurs three times here but only
// twice with the same rights, since the rook walk gave up the king-side rights.
TEST_F(ChessEngineTests, CastlingRightsMakeAPositionDifferent) {
    ChessEngine engine;
    ASSERT_TRUE(engine.setPGN("1. Nf3 Nf6 2. Rg1 Rg8 3. Rh1 Rh8 4. Ng1 Ng8 5. Nf3 Nf6 6. Ng1 Ng8 *"));
    ASSERT_TRUE(engine.canPlay());
    
    ASSERT_TRUE(engine.setPGN("1. Nf3 Nf6 2. Rg1 Rg8 3. Rh1 Rh8 4. Ng1 Ng8 5. Nf3 Nf6 6. Ng1 Ng8 7. Nf3 Nf6 8. Ng1 Ng8 *"));
    ASSERT_FALSE(engine.canPlay());
}
