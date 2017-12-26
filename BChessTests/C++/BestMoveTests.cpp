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

static void assertBestMove(std::string fen, std::string finalFEN, std::string expectedMove, std::vector<std::string> expectedLine, Configuration config) {
    ChessBoard board;
    ASSERT_TRUE(FFEN::setFEN(fen, board));
    std::string boardFEN = FFEN::getFEN(board);
    ASSERT_STREQ(boardFEN.c_str(), fen.c_str());

    ChessMinMaxSearch search;
    search.config = config;

    MinMaxVariation<MoveList> pv;
    
    search.alphabeta(board, 0, board.color == WHITE, pv);
    
    // Assert the best move
    auto actualMove = FPGN::to_string(pv.moves.bestMove());
    ASSERT_STREQ(expectedMove.c_str(), actualMove.c_str());
    
    // Assert the best line
    ASSERT_EQ(expectedLine.size(), pv.moves.count);

    for (int index=0; index<expectedLine.size(); index++) {
        auto lineMove = FPGN::to_string(pv.moves[index]);
        ASSERT_STREQ(expectedLine[index].c_str(), lineMove.c_str());
    }
    
    // Now play the moves to reach the final position
    ChessBoard finalBoard = board;
    for (int index=0; index<pv.moves.count; index++) {
        auto move = pv.moves[index];
        finalBoard.move(move);
    }
    auto finalBoardFEN = FFEN::getFEN(finalBoard);
    ASSERT_STREQ(finalFEN.c_str(), finalBoardFEN.c_str());
}

static void assertBestMove(std::string fen, std::string finalFEN, std::string bestMove, std::vector<std::string> bestLine) {
    assertBestMove(fen, finalFEN, bestMove, bestLine, Configuration());
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
TEST(BestMove, PawnForkQueenAndKing) {
    std::string start = "8/8/8/1q1k4/8/2P5/1N6/4K3 w - - 0 1";
    std::string end = "8/8/8/8/2k5/8/8/4K3 w - - 0 3";
    assertBestMove(start, end, "c3c4",  { "c3c4", "Qb5xc4", "Nb2xc4", "Kd5xc4" });
}

TEST(BestMove, KnightEscapeAttackByPawn) {
    std::string start = "r1bqkbnr/pppp1ppp/2n5/3P4/8/8/PPP2PPP/RNBQKBNR b KQkq - 0 4";
    std::string end = "r1bqkb1r/pppp1ppp/8/n2Q4/8/2N5/PPP1NPPP/R1B1KB1R b KQkq - 0 7";
    // Note: without quiescence search, the engine wants to do Bf8b4 but actually this leads into material loss way down the tree.
    // The best move here is moving the knight out of c6.
    assertBestMove(start, end, "Nc6a5",  { "Nc6a5", "Nb1c3", "Ng8e7", "Ng1e2", "Ne7xd5", "Qd1xd5" });
}

// In this situation, we are trying to see if the engine is able to see
// that moving the pawn c2c3 can actually cause a double attacks against black.
TEST(BestMove, MovePawnToAttackBishop) {
    std::string start = "r1bqk1nr/pppp1ppp/2n5/3P4/1b6/8/PPP2PPP/RNBQKBNR w KQkq - 1 5";
    std::string end = "r1bk2nr/ppp2ppp/2p5/b7/8/2P5/PP3PPP/RNB1KBNR w KQ - 0 8";
    assertBestMove(start, end, "c2c3",  { "c2c3", "Bb4a5", "d5xc6", "d7xc6", "Qd1xd8", "Ke8xd8" });
}

TEST(BestMove, BlackMoveToMateNonSorted) {
    std::string start = "8/6k1/p7/2rbp3/8/7P/5qPK/8 b - - 3 39";
    std::string end = "8/6k1/8/p1rbp3/7P/8/6qK/8 w - - 0 41";
    Configuration config;
    config.sortMoves = false;
    assertBestMove(start, end, "a6a5",  { "a6a5", "h3h4", "Qf2xg2" }, config );
}

TEST(BestMove, BlackMoveToMate) {
    std::string start = "8/6k1/p7/2rbp3/8/7P/5qPK/8 b - - 3 39";
    std::string end = "8/6k1/p7/2rbp3/8/7P/6qK/8 w - - 0 40";
    Configuration config;
    config.sortMoves = true;
    assertBestMove(start, end, "Qf2xg2",  { "Qf2xg2" }, config );
}

