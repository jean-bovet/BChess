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

static void assertBestMove(std::string fen, std::string expectedFinalFEN, std::string expectedLine, Configuration config) {
    ChessBoard board;
    ASSERT_TRUE(FFEN::setFEN(fen, board));
    std::string boardFEN = FFEN::getFEN(board);
    ASSERT_STREQ(boardFEN.c_str(), fen.c_str());

    ChessMinMaxSearch search;
    search.config = config;

    ChessMinMaxSearch::Variation pv;
    ChessMinMaxSearch::Variation bv;
    
    HistoryPtr history = NEW_HISTORY;
    search.alphabeta(board, history, 0, board.color == WHITE, pv, bv);
    
//    std::cout << pv.depth << "/" << pv.qsDepth << std::endl;
//    std::cout << pv.moves.description() << std::endl;
    
    // Assert the best line
    ASSERT_STREQ(expectedLine.c_str(), pv.moves.description().c_str());
    
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
    ASSERT_STREQ(expectedFinalFEN.c_str(), finalBoardFEN.c_str());
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
    std::string end = "7k/6p1/5pQ1/8/8/8/8/7K b - - 1 1";
    Configuration config;
    config.maxDepth = 1;
    config.quiescenceSearch = true;
    assertBestMove(start, end, "Qf5g6", config);
}

TEST_F(BestMoveTests, KnightEscapeAttackByPawn) {
    std::string start = "r1bqkbnr/pppp1ppp/2n5/3P4/8/8/PPP2PPP/RNBQKBNR b KQkq - 0 4";
    std::string end = "r1bqkbnr/pp2nppp/2p5/8/8/P7/1PP2PPP/RNBQKBNR w KQkq - 0 7";
    // Note: without quiescence search, the engine wants to do Bf8b4 but actually this leads into material loss way down the tree.
    // The best move here is moving the knight out of c6.
    assertBestMove(start, end, "Nc6e7 a2a3 c7c6 d5xc6 d7xc6");
}

// In this situation, we are trying to see if the engine is able to see
// that moving the pawn c2c3 can actually cause a double attacks against black.
TEST_F(BestMoveTests, MovePawnToAttackBishop) {
    std::string start = "r1bqk1nr/pppp1ppp/2n5/3P4/1b6/8/PPP2PPP/RNBQKBNR w KQkq - 1 5";
    std::string end = "r1b1k1nr/pppp1ppp/8/3Pn3/1q6/8/PP2NPPP/RNBQKB1R w KQkq - 0 8";
    assertBestMove(start, end, "c2c3 Qd8e7 Ng1e2 Nc6e5 c3xb4 Qe7xb4");
}

TEST_F(BestMoveTests, BlackMoveToMateNonSorted) {
    std::string start = "8/6k1/p7/2rbp3/8/7P/5qPK/8 b - - 3 39";
    std::string end = "8/6k1/8/p2bp2P/8/2r5/6qK/8 w - - 0 42";
    Configuration config;
    config.sortMoves = false;
    assertBestMove(start, end, "a6a5 h3h4 Rc5c3 h4h5 Qf2xg2", config );
}

TEST_F(BestMoveTests, BlackMoveToMate) {
    std::string start = "8/6k1/p7/2rbp3/8/7P/5qPK/8 b - - 3 39";
    std::string end = "8/6k1/p7/2rbp3/8/7P/6qK/8 w - - 0 40";
    Configuration config;
    config.sortMoves = true;
    assertBestMove(start, end, "Qf2xg2", config );
}

