//
//  FTests.hpp
//  BChess
//
//  Created by Jean Bovet on 12/2/17.
//  Copyright © 2017 Jean Bovet. All rights reserved.
//

#include <gtest/gtest.h>

#include "FFEN.hpp"
#include "FPGN.hpp"

#include "ChessEngine.hpp"

#include <set>
#include <vector>

static void assertPGNGame(const char *pgnGame, std::string expectedFEN) {
    ChessGame game;
    std::string gameS(pgnGame);
    EXPECT_TRUE(FPGN::setGame(gameS, game));
    
    // Assert the FEN for the end position
    std::string actualFEN = FFEN::getFEN(game.board);
    EXPECT_STREQ(expectedFEN.c_str(), actualFEN.c_str());
}

static void assertOutputPGN(const char *pgnGame, std::string expectedFEN, std::string outputPGN) {
    ChessGame game;
    std::string gameS(pgnGame);
    EXPECT_TRUE(FPGN::setGame(gameS, game));
    
    // Assert the FEN for the end position
    std::string actualFEN = FFEN::getFEN(game.board);
    EXPECT_STREQ(expectedFEN.c_str(), actualFEN.c_str());
    
    auto generatedPGN = FPGN::getGame(game, FPGN::Formatting::history);
    EXPECT_STREQ(outputPGN.c_str(), generatedPGN.c_str());
    
    // Now let's try again the assert the game using the generated PGN and the expected FEN of the game
    // in the final position.
    assertPGNGame(generatedPGN.c_str(), expectedFEN);
}

static void assertMovetextSingle(std::string pgn, std::string expectedMove) {
    Move move;
    
    auto fpgn = FPGN(pgn);
    
    if (expectedMove.size() == 0) {
        EXPECT_FALSE(fpgn.parseMove(move));
    } else {
        EXPECT_TRUE(fpgn.parseMove(move));
        auto moveDescription = FPGN::to_string(move);
        EXPECT_STREQ(expectedMove.c_str(), moveDescription.c_str());
    }
}

class PGN : public testing::Test {
protected:
    virtual void SetUp() {
        ChessEngine::initialize();
    }
};

TEST_F(PGN, SingleMove) {
    auto fpgn = FPGN("1. e4 e5");
    EXPECT_TRUE(fpgn.parseMoveText());
}

TEST_F(PGN, SingleMoveWithComments) {
    auto fpgn = FPGN("1. e4 {hello} e5 {world}");
    EXPECT_TRUE(fpgn.parseMoveText());
}

TEST_F(PGN, SingleMoveForBlack) {
    auto fpgn = FPGN("[FEN \"rnbqkbnr/pppppppp/8/8/4P3/8/PPPP1PPP/RNBQKBNR b KQkq - 0 1\"] 1... e5]");
    EXPECT_TRUE(fpgn.parseTag());
    EXPECT_TRUE(fpgn.parseMoveText());
}

TEST_F(PGN, Moves) {
    assertMovetextSingle("e4", "e2e4");
    assertMovetextSingle("e5", "");
    
    assertMovetextSingle("Nf3", "Ng1f3");
    assertMovetextSingle("Ngf3", "Ng1f3");
    assertMovetextSingle("Nbf3", "");
    
    assertMovetextSingle("f3", "f2f3");
}

TEST_F(PGN, ParseMoveNumber) {
    unsigned moveNumber = 0;
    bool isMoveForBlack = false;
    
    ASSERT_TRUE(FPGN("1.").parseMoveNumber(moveNumber, isMoveForBlack));
    ASSERT_EQ(1, moveNumber);
    ASSERT_FALSE(isMoveForBlack);

    ASSERT_TRUE(FPGN("1. ").parseMoveNumber(moveNumber, isMoveForBlack));
    ASSERT_EQ(1, moveNumber);
    ASSERT_FALSE(isMoveForBlack);

    ASSERT_TRUE(FPGN("1. e4").parseMoveNumber(moveNumber, isMoveForBlack));
    ASSERT_EQ(1, moveNumber);
    ASSERT_FALSE(isMoveForBlack);

    ASSERT_TRUE(FPGN("24...").parseMoveNumber(moveNumber, isMoveForBlack));
    ASSERT_EQ(24, moveNumber);
    ASSERT_TRUE(isMoveForBlack);
    
    ASSERT_FALSE(FPGN("").parseMoveNumber(moveNumber, isMoveForBlack));
    ASSERT_FALSE(FPGN(".1").parseMoveNumber(moveNumber, isMoveForBlack));
    ASSERT_FALSE(FPGN("1a.").parseMoveNumber(moveNumber, isMoveForBlack));
    ASSERT_FALSE(FPGN("112..").parseMoveNumber(moveNumber, isMoveForBlack));
}

TEST_F(PGN, ParseMove) {
    Move move;
    
    ASSERT_TRUE(FPGN("e4").parseMove(move));
    ASSERT_EQ(squareForName("e2"), MOVE_FROM(move));
    ASSERT_EQ(squareForName("e4"), MOVE_TO(move));
    ASSERT_EQ(PAWN, MOVE_PIECE(move));
    
    auto fpgn = FPGN("e4 e5");
    ASSERT_TRUE(fpgn.parseMove(move));
    fpgn.getGame().move(move, "", false);
    ASSERT_TRUE(fpgn.parseMove(move));
    ASSERT_EQ(squareForName("e7"), MOVE_FROM(move));
    ASSERT_EQ(squareForName("e5"), MOVE_TO(move));
    ASSERT_EQ(PAWN, MOVE_PIECE(move));
    ASSERT_FALSE(fpgn.parseMove(move));
}

constexpr const static char * move1to3 =
"1. e4 e5 2. Nf3 Nc6 3. Bb5 a6 {This opening is called the Ruy Lopez.}\n"
;

constexpr const static char *move1to10 =
"1. e4 e5 2. Nf3 Nc6 3. Bb5 a6 {This opening is called the Ruy Lopez.}\n"
"4. Ba4 Nf6 5. O-O Be7 6. Re1 b5 7. Bb3 d6 8. c3 O-O 9. h3 Nb8 10. d4 Nbd7"
;

constexpr const static char *move1to34 =
"1. e4 e5 2. Nf3 Nc6 3. Bb5 a6 {This opening is called the Ruy Lopez.}\n"
"4. Ba4 Nf6 5. O-O Be7 6. Re1 b5 7. Bb3 d6 8. c3 O-O 9. h3 Nb8 10. d4 Nbd7\n"
"11. c4 c6 12. cxb5 axb5 13. Nc3 Bb7 14. Bg5 b4 15. Nb1 h6 16. Bh4 c5 17. dxe5\n"
"Nxe4 18. Bxe7 Qxe7 19. exd6 Qf6 20. Nbd2 Nxd6 21. Nc4 Nxc4 22. Bxc4 Nb6\n"
"23. Ne5 Rae8 24. Bxf7+ Rxf7 25. Nxf7 Rxe1+ 26. Qxe1 Kxf7 27. Qe3 Qg5 28. Qxg5\n"
"hxg5 29. b3 Ke6 30. a3 Kd6 31. axb4 cxb4 32. Ra5 Nd5 33. f3 Bc8 34. Kf2 Bf5"
;

constexpr const static char *allMoves =
"1. e4 e5 2. Nf3 Nc6 3. Bb5 a6 {This opening is called the Ruy Lopez.}\n"
"4. Ba4 Nf6 5. O-O Be7 6. Re1 b5 7. Bb3 d6 8. c3 O-O 9. h3 Nb8 10. d4 Nbd7\n"
"11. c4 c6 12. cxb5 axb5 13. Nc3 Bb7 14. Bg5 b4 15. Nb1 h6 16. Bh4 c5 17. dxe5\n"
"Nxe4 18. Bxe7 Qxe7 19. exd6 Qf6 20. Nbd2 Nxd6 21. Nc4 Nxc4 22. Bxc4 Nb6\n"
"23. Ne5 Rae8 24. Bxf7+ Rxf7 25. Nxf7 Rxe1+ 26. Qxe1 Kxf7 27. Qe3 Qg5 28. Qxg5\n"
"hxg5 29. b3 Ke6 30. a3 Kd6 31. axb4 cxb4 32. Ra5 Nd5 33. f3 Bc8 34. Kf2 Bf5\n"
"35. Ra7 g6 36. Ra6+ Kc5 37. Ke1 Nf4 38. g3 Nxh3 39. Kd2 Kb5 40. Rd6 Kc5 41. Ra6\n"
"Nf2 42. g4 Bd3 43. Re6 1/2-1/2"
;

TEST_F(PGN, GameInput) {
    assertPGNGame(move1to3, "r1bqkbnr/1ppp1ppp/p1n5/1B2p3/4P3/5N2/PPPP1PPP/RNBQK2R w KQkq - 0 4");

    assertPGNGame(move1to10, "r1bq1rk1/2pnbppp/p2p1n2/1p2p3/3PP3/1BP2N1P/PP3PP1/RNBQR1K1 w - - 1 11");

    assertPGNGame(move1to34, "8/6p1/3k4/R2n1bp1/1p6/1P3P1P/5KP1/8 w - - 3 35");

    assertPGNGame(allMoves, "8/8/4R1p1/2k3p1/1p4P1/1P1b1P2/3K1n2/8 b - - 2 43");
}

TEST_F(PGN, GameOutput) {
    assertOutputPGN(move1to3, "r1bqkbnr/1ppp1ppp/p1n5/1B2p3/4P3/5N2/PPPP1PPP/RNBQK2R w KQkq - 0 4", "1. e4 e5 2. Nf3 Nc6 3. Bb5 a6 {This opening is called the Ruy Lopez.} *");
    
    assertOutputPGN(move1to10, "r1bq1rk1/2pnbppp/p2p1n2/1p2p3/3PP3/1BP2N1P/PP3PP1/RNBQR1K1 w - - 1 11", "1. e4 e5 2. Nf3 Nc6 3. Bb5 a6 {This opening is called the Ruy Lopez.} 4. Ba4 Nf6 5. O-O Be7 6. Re1 b5 7. Bb3 d6 8. c3 O-O 9. h3 Nb8 10. d4 Nbd7 *");

    assertOutputPGN(move1to34, "8/6p1/3k4/R2n1bp1/1p6/1P3P1P/5KP1/8 w - - 3 35", "1. e4 e5 2. Nf3 Nc6 3. Bb5 a6 {This opening is called the Ruy Lopez.} 4. Ba4 Nf6 5. O-O Be7 6. Re1 b5 7. Bb3 d6 8. c3 O-O 9. h3 Nb8 10. d4 Nbd7 11. c4 c6 12. cxb5 axb5 13. Nc3 Bb7 14. Bg5 b4 15. Nb1 h6 16. Bh4 c5 17. dxe5 Nxe4 18. Bxe7 Qxe7 19. exd6 Qf6 20. Nbd2 Nxd6 21. Nc4 Nxc4 22. Bxc4 Nb6 23. Ne5 Rae8 24. Bxf7+ Rxf7 25. Nxf7 Rxe1+ 26. Qxe1 Kxf7 27. Qe3 Qg5 28. Qxg5 hxg5 29. b3 Ke6 30. a3 Kd6 31. axb4 cxb4 32. Ra5 Nd5 33. f3 Bc8 34. Kf2 Bf5 *");

    assertOutputPGN(allMoves, "8/8/4R1p1/2k3p1/1p4P1/1P1b1P2/3K1n2/8 b - - 2 43", "1. e4 e5 2. Nf3 Nc6 3. Bb5 a6 {This opening is called the Ruy Lopez.} 4. Ba4 Nf6 5. O-O Be7 6. Re1 b5 7. Bb3 d6 8. c3 O-O 9. h3 Nb8 10. d4 Nbd7 11. c4 c6 12. cxb5 axb5 13. Nc3 Bb7 14. Bg5 b4 15. Nb1 h6 16. Bh4 c5 17. dxe5 Nxe4 18. Bxe7 Qxe7 19. exd6 Qf6 20. Nbd2 Nxd6 21. Nc4 Nxc4 22. Bxc4 Nb6 23. Ne5 Rae8 24. Bxf7+ Rxf7 25. Nxf7 Rxe1+ 26. Qxe1 Kxf7 27. Qe3 Qg5 28. Qxg5 hxg5 29. b3 Ke6 30. a3 Kd6 31. axb4 cxb4 32. Ra5 Nd5 33. f3 Bc8 34. Kf2 Bf5 35. Ra7 g6 36. Ra6+ Kc5 37. Ke1 Nf4 38. g3 Nxh3 39. Kd2 Kb5 40. Rd6 Kc5 41. Ra6 Nf2 42. g4 Bd3 43. Re6 1/2-1/2");
}

TEST_F(PGN, GameWithBlackFromFEN) {
    ChessGame game;
    game.setFEN("1K1k4/1P6/8/8/8/8/r7/2R5 w - - 0 1");
    game.move("c1", "d1");
    
    auto pgn = FPGN::getGame(game);
    ASSERT_EQ("[Event \"\"]\n[Site \"\"]\n[Date \"\"]\n[Round \"\"]\n[White \"\"]\n[Black \"\"]\n[Result \"\"]\n[FEN \"1K1k4/1P6/8/8/8/8/r7/2R5 w - - 0 1\"]\n[Setup \"1\"]\n\n 1. Rd1+ *", pgn);
}

TEST_F(PGN, GameWithBlackPromotion) {
    ChessGame game;
    ASSERT_TRUE(FPGN::setGame("1.e4 Nf6 2.Nc3 Nxe4 3.Nxe4 d5 4.Nc3 Qd6 5.Nf3 h5 6.d4 Qd8 7.Bb5+ c6 8.Ba4 b5 9.Bb3 a5 10.a4 b4 11.Na2 Bg4 12.Qd3 Bxf3 13.Qxf3 h4 14.h3 Qd6 15.Bf4 Qe6+ 16.Be3 Qd6 17.O-O g6 18.c4 bxc3 19.bxc3 Nd7 20.c4 dxc4 21.Bxc4 Qf6 22.Qg4 e5 23.Rfe1 Qg7 24.dxe5 Nc5 25.Bxc5 Bxc5 26.e6 Bd4 27.exf7+ Kf8 28.Qe6 Qf6 29.Rad1 Qxe6 30.Bxe6 c5 31.Bd5 Rb8 32.Nc1 Rh5 33.Bc4 Rf5 34.Re2 Rf4 35.Rde1 Bxf2+ 36.Rxf2 Rxc4 37.Nd3 Kg7 38.Re7 Kf8 39.Re6 Rxa4 40.Nxc5 Ra1+ 41.Kh2 Rd1 42.Ne4 Kg7 43.Ng5 Rf8 44.Rfe2 Rxf7 45.Nxf7 Kxf7 46.R6e4 Ra1 47.Rxh4 Kg8 48.Rf2 Kg7 49.Rhf4 a4 50.Rf7+ Kh6 51.R2f4 a3 52.Rg4 a2 53.Rf6 Rh1+ 54.Kxh1 *", game));
    
    auto move = createPromotion(squareForName("a2"), squareForName("a1"), BLACK, PAWN, QUEEN);
    game.move(move, "", false);
    
    auto pgn = FPGN::getGame(game, FPGN::Formatting::history);
    ASSERT_EQ(pgn, "1. e4 Nf6 2. Nc3 Nxe4 3. Nxe4 d5 4. Nc3 Qd6 5. Nf3 h5 6. d4 Qd8 7. Bb5+ c6 8. Ba4 b5 9. Bb3 a5 10. a4 b4 11. Na2 Bg4 12. Qd3 Bxf3 13. Qxf3 h4 14. h3 Qd6 15. Bf4 Qe6+ 16. Be3 Qd6 17. O-O g6 18. c4 bxc3 19. bxc3 Nd7 20. c4 dxc4 21. Bxc4 Qf6 22. Qg4 e5 23. Rfe1 Qg7 24. dxe5 Nc5 25. Bxc5 Bxc5 26. e6 Bd4 27. exf7+ Kf8 28. Qe6 Qf6 29. Rad1 Qxe6 30. Bxe6 c5 31. Bd5 Rb8 32. Nc1 Rh5 33. Bc4 Rf5 34. Re2 Rf4 35. Rde1 Bxf2+ 36. Rxf2 Rxc4 37. Nd3 Kg7 38. Re7 Kf8 39. Re6 Rxa4 40. Nxc5 Ra1+ 41. Kh2 Rd1 42. Ne4 Kg7 43. Ng5 Rf8 44. Rfe2 Rxf7 45. Nxf7 Kxf7 46. Re6e4 Ra1 47. Rxh4 Kg8 48. Rf2 Kg7 49. Rhf4 a4 50. Rf7+ Kh6 51. Rf2f4 a3 52. Rg4 a2 53. Rf6 Rh1+ 54. Kxh1 a1=Q+ *");
}

TEST_F(PGN, OutputFromInitialPosition) {
    ChessGame game;
    ASSERT_EQ(StartFEN, game.initialFEN);

    ASSERT_EQ("*", FPGN::getGame(game, FPGN::Formatting::history));

    game.move("e2", "e4");
    
    ASSERT_EQ("1. e4 *", FPGN::getGame(game, FPGN::Formatting::history));
}

TEST_F(PGN, InputFromInitialPosition) {
    ChessGame game;
    FPGN::setGame("*", game);
    ASSERT_EQ(StartFEN, game.initialFEN);
    
    FPGN::setGame("1. e4 *", game);

    ASSERT_EQ("1. e4 *", FPGN::getGame(game, FPGN::Formatting::history));
}

TEST_F(PGN, OutputFromPosition) {
    std::string fen = "r1bqkbnr/ppp1pppp/2n5/3p4/4P3/5N2/PPPP1PPP/RNBQKB1R w KQkq - 2 3";
    
    ChessGame game;
    game.setFEN(fen);
    ASSERT_EQ(fen.c_str(), game.initialFEN);
    
    auto pgn = FPGN::getGame(game);
    ASSERT_EQ("[Event \"\"]\n[Site \"\"]\n[Date \"\"]\n[Round \"\"]\n[White \"\"]\n[Black \"\"]\n[Result \"\"]\n[FEN \"r1bqkbnr/ppp1pppp/2n5/3p4/4P3/5N2/PPPP1PPP/RNBQKB1R w KQkq - 2 3\"]\n[Setup \"1\"]\n\n *", pgn);
}

TEST_F(PGN, InputFromPosition) {
    auto fpgn = FPGN("[FEN \"r1bqkbnr/ppp1pppp/2n5/3p4/4P3/5N2/PPPP1PPP/RNBQKB1R w KQkq - 2 3\"]\n*");
    EXPECT_TRUE(fpgn.parseTag());
    
    ASSERT_EQ("r1bqkbnr/ppp1pppp/2n5/3p4/4P3/5N2/PPPP1PPP/RNBQKB1R w KQkq - 2 3", fpgn.getGame().initialFEN);
    ASSERT_EQ(0, fpgn.getGame().getNumberOfMoves());
}

TEST_F(PGN, InputMultipleGames) {
    std::string pgn = "[Title \"a\"] 1. e4 e5 [Title \"b\"] 1. d4 d5";
    std::vector<ChessGame> games;
    ASSERT_TRUE(FPGN::setGames(pgn, games));
    ASSERT_EQ(2, games.size());
}

TEST_F(PGN, PGNWithSimpleWhiteVariation) {
    std::string pgn = "1. e4 (1. d4) *";
    
    ChessGame game;
    ASSERT_TRUE(FPGN::setGame(pgn, game));
    
    ASSERT_EQ(1, game.getNumberOfMoves());
    ASSERT_EQ(2, game.getRoot().variations.size());
    
    auto pgnAgain = FPGN::getGame(game, FPGN::Formatting::history);
    ASSERT_EQ("1. e4 (1. d4) *", pgnAgain);
}

TEST_F(PGN, PGNWithSimpleBlackVariation) {
    std::string pgn = "1. e4 e5 (1... c5)";
    
    ChessGame game;
    ASSERT_TRUE(FPGN::setGame(pgn, game));
    
    ASSERT_EQ(2, game.getNumberOfMoves());
    ASSERT_EQ(1, game.getRoot().variations.size());
    ASSERT_EQ(2, game.getRoot().variations[0].variations.size());

    auto pgnAgain = FPGN::getGame(game, FPGN::Formatting::history);
    ASSERT_EQ("1. e4 e5 (1... c5) *", pgnAgain);
}

TEST_F(PGN, PGNWithVariation1) {
    std::string pgn = "1. e4 e5 2. Nc3 Nf6 3. f4 d5 4. fxe5 Nxe4 5. Qf3 Nxc3 (5... Nc6) 6. bxc3 Be7";

    ChessGame game;
    ASSERT_TRUE(FPGN::setGame(pgn, game));
    
    ASSERT_EQ(12, game.getNumberOfMoves());

    auto pgnAgain = FPGN::getGame(game, FPGN::Formatting::history);
    ASSERT_EQ("1. e4 e5 2. Nc3 Nf6 3. f4 d5 4. fxe5 Nxe4 5. Qf3 Nxc3 (5... Nc6) 6. bxc3 Be7 *", pgnAgain);
}

TEST_F(PGN, PGNWithVariation2) {
    std::string pgn = "1.e4 e5 { Normal opening } 2.Nc3 ( 2.Nf3 Nc6 3.Nc3 Nf6 ) *";

    ChessGame game;
    ASSERT_TRUE(FPGN::setGame(pgn, game));
    
    ASSERT_EQ(3, game.getNumberOfMoves());

    auto pgnAgain = FPGN::getGame(game, FPGN::Formatting::history);
    ASSERT_EQ("1. e4 e5 { Normal opening } 2. Nc3 (2. Nf3 Nc6 3. Nc3 Nf6) *", pgnAgain);
}

TEST_F(PGN, LineFromCursor) {
    ChessGame game;
    ASSERT_TRUE(FPGN::setGame(move1to3, game));
    
    auto line = FPGN::getGame(game, FPGN::Formatting::line, 2);
    ASSERT_EQ("Nf3 Nc6 Bb5 a6 {This opening is called the Ruy Lopez.}", line);
}

TEST_F(PGN, MoveWithNumberInFront) {
    std::string pgn = "1.e4 1... e5 2.Nf3 2... Nc6 *";

    ChessGame game;
    ASSERT_TRUE(FPGN::setGame(pgn, game));
    
    ASSERT_EQ(4, game.getNumberOfMoves());

    auto pgnAgain = FPGN::getGame(game, FPGN::Formatting::history);
    ASSERT_EQ("1. e4 e5 2. Nf3 Nc6 *", pgnAgain);
}

TEST_F(PGN, Game1) {
    std::string pgn = "1. e4 e5 2. Nf3 Nc6 3. Nc3 Nf6 4. Bc4 Nxe4 5. Nxe4 d5 6. Bxd5 Qxd5 7. Nc3 Qd6 8. O-O Bg4 9. h3 Bh5 10. Nb5 Qe7 11. c3 O-O-O 12. Qc2 Qf6 13. Nh2 Be2 14. Nxa7+ Nxa7 15. Re1 Bd3 16. Qa4 Bc5 17. Ng4 Qh4 18. b4 Bb6 19. Rxe5 h5 20. Ne3 Rh6 21. Bb2 Rf6 22. f3 Rxf3 23. Re8 Qf2+ 24. Kh1 Rg3 25. Rd1 Qxg2+ 26. Nxg2 Rxh3# 0-1";
    
    ChessGame game;
    ASSERT_TRUE(FPGN::setGame(pgn, game));
    
    ASSERT_EQ(52, game.getNumberOfMoves());

    auto pgnAgain = FPGN::getGame(game, FPGN::Formatting::history);
    ASSERT_EQ("1. e4 e5 2. Nf3 Nc6 3. Nc3 Nf6 4. Bc4 Nxe4 5. Nxe4 d5 6. Bxd5 Qxd5 7. Nc3 Qd6 8. O-O Bg4 9. h3 Bh5 10. Nb5 Qe7 11. c3 O-O-O 12. Qc2 Qf6 13. Nh2 Be2 14. Nxa7+ Nxa7 15. Re1 Bd3 16. Qa4 Bc5 17. Ng4 Qh4 18. b4 Bb6 19. Rxe5 h5 20. Ne3 Rh6 21. Bb2 Rf6 22. f3 Rxf3 23. Re8 Qf2+ 24. Kh1 Rg3 25. Rd1 Qxg2+ 26. Nxg2 Rxh3# 0-1", pgnAgain);
}

TEST_F(PGN, MovesWithAnnotationSymbols) {
    std::string pgn = "1.e4 e5! 2.Nf3?? Nc6?! *";

    ChessGame game;
    ASSERT_TRUE(FPGN::setGame(pgn, game));
    
    ASSERT_EQ(4, game.getNumberOfMoves());

    auto pgnAgain = FPGN::getGame(game, FPGN::Formatting::history);
    ASSERT_EQ("1. e4 e5 2. Nf3 Nc6 *", pgnAgain);
}

TEST_F(PGN, MovesWithConsecutiveComments) {
    std::string pgn = "1.e4 e5 2.Nf3 Nc6 { and } { the } { game } { continues } *";

    ChessGame game;
    ASSERT_TRUE(FPGN::setGame(pgn, game));
    
    ASSERT_EQ(4, game.getNumberOfMoves());

    auto pgnAgain = FPGN::getGame(game, FPGN::Formatting::history);
    ASSERT_EQ("1. e4 e5 2. Nf3 Nc6 { and  the  game  continues } *", pgnAgain);
}
