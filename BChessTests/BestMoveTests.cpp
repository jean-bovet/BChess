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

class BestMoveTests: public ::testing::Test {
public:
    void SetUp() {
        ChessEngine::initialize();
    }
};

static void assertBestMove(std::string fen, std::string expectedFinalFEN, std::string expectedLine, Configuration config, TranspositionTable &table) {
    ChessBoard board;
    ASSERT_TRUE(FFEN::setFEN(fen, board));
    std::string boardFEN = FFEN::getFEN(board);
    ASSERT_EQ(boardFEN, fen);

    ChessMinMaxSearch search;
    search.config = config;

    ChessMinMaxSearch::Variation pv;
    ChessMinMaxSearch::Variation bv;
    
    HistoryPtr history = NEW_HISTORY;
    search.alphabeta(board, history, table, 0, board.color == WHITE, pv, bv);
    
//    std::cout << pv.depth << "/" << pv.qsDepth << std::endl;
//    std::cout << pv.moves.description() << std::endl;
    
    // Assert the best line
    ASSERT_EQ(expectedLine, pv.moves.description());
    
    // Assert the best move
    auto actualMove = FPGN::to_string(pv.moves.bestMove());
    ASSERT_TRUE(expectedLine.compare(0, actualMove.length(), actualMove) == 0);

    // Now play the moves to reach the final position
    ChessBoard finalBoard = board;
    for (int index=0; index<pv.moves.count; index++) {
        auto move = pv.moves[index];
        finalBoard.move(move);
    }
    auto finalBoardFEN = FFEN::getFEN(finalBoard);
    ASSERT_EQ(expectedFinalFEN, finalBoardFEN);
}

static void assertBestMove(std::string fen, std::string expectedFinalFEN, std::string expectedLine, Configuration config) {
    TranspositionTable table;
    assertBestMove(fen, expectedFinalFEN, expectedLine, config, table);
}

static void assertBestMove(std::string fen, std::string expectedFinalFEN, std::string expectedLine) {
    assertBestMove(fen, expectedFinalFEN, expectedLine, Configuration());
}

/** Assert the following position and evaluate the best move for white
 which is c3c4:
 ........
 ........
 ........
 .♛.♚....
 ........
 ..♙.....
 .♘......
 ....♔...
 */
TEST_F(BestMoveTests, PawnForkQueenAndKing) {
    std::string start = "8/8/8/1q1k4/8/2P5/1N6/4K3 w - - 0 1";
    std::string end = "8/8/8/8/2k5/8/8/4K3 w - - 0 3";
    assertBestMove(start, end, "c3c4 Qb5xc4 Nb2xc4 Kd5xc4");
}

TEST_F(BestMoveTests, QueenEatPawn) {
    std::string start = "7k/6p1/5p2/5Q2/8/8/8/7K w - - 0 1";
    std::string end = "7k/6p1/5Q2/8/8/8/8/7K b - - 0 1";
    Configuration config;
    config.maxDepth = 1;
    config.quiescenceSearch = false;
    assertBestMove(start, end, "Qf5xf6", config);
}

TEST_F(BestMoveTests, QueenShouldNotEatPawn) {
    std::string start = "7k/6p1/5p2/5Q2/8/8/8/7K w - - 0 1";
    std::string end = "7k/6p1/5p2/5Q2/8/8/8/6K1 b - - 1 1";
    Configuration config;
    config.maxDepth = 1;
    config.quiescenceSearch = true;
    assertBestMove(start, end, "Kh1g1", config);
}

TEST_F(BestMoveTests, KnightEscapeAttackByPawn) {
    std::string start = "r1bqkbnr/pppp1ppp/2n5/3P4/8/8/PPP2PPP/RNBQKBNR b KQkq - 0 4";
    std::string end = "r1bqkbnr/pppp1ppp/8/3P4/8/5Q2/PPP2PPP/RNB1KB1R b KQkq - 0 6";
    // Note: without quiescence search, the engine wants to do Bf8b4 but actually this leads into material loss way down the tree.
    // The best move here is moving the knight out of c6.
    assertBestMove(start, end, "Nc6e5 Ng1f3 Ne5xf3 Qd1xf3");
}

// In this situation, we are trying to see if the engine is able to see
// that moving the pawn c2c3 can actually cause a double attacks against black.
TEST_F(BestMoveTests, MovePawnToAttackBishop) {
    std::string start = "r1bqk1nr/pppp1ppp/2n5/3P4/1b6/8/PPP2PPP/RNBQKBNR w KQkq - 1 5";
    std::string end = "r1bk2nr/ppp2ppp/2p5/2b5/8/2P5/PP3PPP/RNB1KBNR w KQ - 0 8";
    assertBestMove(start, end, "c2c3 Bb4c5 d5xc6 d7xc6 Qd1xd8 Ke8xd8");
}

TEST_F(BestMoveTests, BlackMoveToMateNonSorted) {
    std::string start = "8/6k1/p7/2rbp3/8/7P/5qPK/8 b - - 3 39";
    std::string end = "8/6k1/p7/2rb3P/8/4p3/6qK/8 w - - 0 42";
    Configuration config;
    config.sortMoves = false;
    assertBestMove(start, end, "e5e4 h3h4 e4e3 h4h5 Qf2xg2", config );
}

TEST_F(BestMoveTests, BlackMoveToMate) {
    std::string start = "8/6k1/p7/2rbp3/8/7P/5qPK/8 b - - 3 39";
    std::string end = "8/6k1/p7/2rbp3/8/7P/6qK/8 w - - 0 40";
    Configuration config;
    config.sortMoves = true;
    assertBestMove(start, end, "Qf2xg2", config );
}

TEST_F(BestMoveTests, WhiteThreatenMate) {
    std::string start = "3r1k1r/1pp2ppp/pq6/3P4/5Q2/P1P4P/1P1R2P1/5R1K b - - 2 24";
    std::string end = "5k1r/1pp2ppp/p2r4/3P4/8/P1P4P/1P1R2P1/4R2K w - - 0 27";
    // Note: black king is about to get mate.
    assertBestMove(start, end, "Rd8d7 Rf1e1 Qb6d6 Qf4xd6 Rd7xd6");
}

TEST_F(BestMoveTests, WithAndWithoutTT) {
    std::string start = "rnbqkb1r/ppp1pppp/5n2/3p4/3P4/5N2/PPP1PPPP/RNBQKB1R w KQkq - 0 3";
    std::string end = "rnbqkb1r/ppp1pppp/5n2/3p4/3P4/2N2N2/PPP1PPPP/R1BQKB1R b KQkq - 1 3";
    Configuration config;
    config.maxDepth = 5;
    config.transpositionTable = false;
    assertBestMove(start, end, "Nb1c3 Nb8d7 Qd1d3 e7e6 e2e4 d5xe4 Nc3xe4 Nf6xe4 Qd3xe4", config);
    
    config.transpositionTable = true;
    TranspositionTable table;
    assertBestMove(start, end, "Nb1c3 Nb8d7 e2e3 a7a6 Bf1d3", config, table);
//    assertBestMove(start, end, "Nb1c3", config, table);
}
