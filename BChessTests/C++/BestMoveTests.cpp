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

static void assertBestMove(std::string fen, std::string finalFEN, std::string bestMove, std::vector<std::string> bestLine, Configuration config) {
    ChessBoard board;
    ASSERT_TRUE(FFEN::setFEN(fen, board));
    std::string boardFEN = FFEN::getFEN(board);
    ASSERT_STREQ(boardFEN.c_str(), fen.c_str());

    ChessMinMaxSearch search;
    search.config = config;

    ChessEvaluation evaluation = search.alphabeta(board, 0, board.color == WHITE);
    
    // Assert the best move
    auto actualMove = FPGN::to_string(evaluation.line.moves[0]);
    ASSERT_STREQ(actualMove.c_str(), bestMove.c_str());
    
    // Assert the best line
    ASSERT_EQ(evaluation.line.count, bestLine.size());

    for (int index=0; index<bestLine.size(); index++) {
        auto lineMove = FPGN::to_string(evaluation.line.moves[index]);
        ASSERT_STREQ(lineMove.c_str(), bestLine[index].c_str());
    }
    
    // Now play the moves to reach the final position
    ChessBoard finalBoard = board;
    for (int index=0; index<evaluation.line.count; index++) {
        auto move = evaluation.line.moves[index];
        finalBoard.move(move);
    }
    auto finalBoardFEN = FFEN::getFEN(finalBoard);
    ASSERT_STREQ(finalBoardFEN.c_str(), finalFEN.c_str());
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
    std::string end = "r1bqk1nr/pp1p1ppp/8/3Q4/8/b7/1P3PPP/RNB1KBNR w KQkq - 0 9";
    // Note: without quiescence search, the engine wants to do Bf8b4 but actually this leads into material loss way down the tree.
    // The best move here is moving the knight out of c6.
    assertBestMove(start, end, "Nc6e7",  { "Nc6e7", "a2a3", "c7c6", "c2c4", "c6xd5", "c4xd5", "Ne7xd5", "Qd1xd5", "Bf8xa3" });
}

// In this situation, we are trying to see if the engine is able to see
// that moving the pawn c2c3 can actually cause a double attacks against black.
TEST(BestMove, MovePawnToAttackBishop) {
    std::string start = "r1bqk1nr/pppp1ppp/2n5/3P4/1b6/8/PPP2PPP/RNBQKBNR w KQkq - 1 5";
    std::string end = "r1bqk1nr/pppp1ppp/8/n1bP4/8/N1P5/PP3PPP/R1BQKBNR w KQkq - 3 7";
    assertBestMove(start, end, "c2c3",  { "c2c3", "Bb4c5", "Nb1a3", "Nc6a5" });
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

