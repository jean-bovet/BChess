//
//  FTests.hpp
//  BChess
//
//  Created by Jean Bovet on 12/2/17.
//  Copyright © 2017 Jean Bovet. All rights reserved.
//

#include <gtest/gtest.h>

#include "FBoard.hpp"
#include "FFEN.hpp"
#include "FMinimax.hpp"
#include "FMoveGenerator.hpp"
#include "FPGN.hpp"
#include "FEvaluate.hpp"

#include <set>
#include <vector>

TEST(Evaluation, BonusPosition) {
    ASSERT_EQ(Evaluate::getBonus(PAWN, Color::WHITE, b2), 10);
    ASSERT_EQ(Evaluate::getBonus(PAWN, Color::BLACK, b2), 50);
}

TEST(Move, InvalidMove) {
    Move m = 0;
    ASSERT_FALSE(MOVE_ISVALID(m));
}

TEST(Move, SimpleMove) {
    Move m = createMove(12, 62, BLACK, BISHOP);
    ASSERT_EQ(MOVE_FROM(m), 12);
    ASSERT_EQ(MOVE_TO(m), 62);
    ASSERT_EQ(MOVE_COLOR(m), BLACK);
    ASSERT_EQ(MOVE_PIECE(m), BISHOP);
    ASSERT_FALSE(MOVE_IS_CAPTURE(m));
    ASSERT_FALSE(MOVE_IS_ENPASSANT(m));
    ASSERT_TRUE(MOVE_ISVALID(m));
}

TEST(Move, MoveCapture) {
    Move m = createCapture(12, 62, BLACK, BISHOP, ROOK);
    ASSERT_EQ(MOVE_FROM(m), 12);
    ASSERT_EQ(MOVE_TO(m), 62);
    ASSERT_EQ(MOVE_COLOR(m), BLACK);
    ASSERT_EQ(MOVE_PIECE(m), BISHOP);
    ASSERT_EQ(MOVE_CAPTURED_PIECE(m), ROOK);
    ASSERT_TRUE(MOVE_IS_CAPTURE(m));
    ASSERT_FALSE(MOVE_IS_ENPASSANT(m));
    ASSERT_TRUE(MOVE_ISVALID(m));
}

TEST(Move, MoveEnPassant) {
    Move m = createEnPassant(12, 62, BLACK, BISHOP);
    ASSERT_EQ(MOVE_FROM(m), 12);
    ASSERT_EQ(MOVE_TO(m), 62);
    ASSERT_EQ(MOVE_COLOR(m), BLACK);
    ASSERT_EQ(MOVE_PIECE(m), BISHOP);
    ASSERT_TRUE(MOVE_IS_CAPTURE(m));
    ASSERT_TRUE(MOVE_IS_ENPASSANT(m));
    ASSERT_TRUE(MOVE_ISVALID(m));
}

TEST(Move, MovePromotion) {
    Move m = createPromotion(12, 62, BLACK, PAWN, ROOK);
    ASSERT_EQ(MOVE_FROM(m), 12);
    ASSERT_EQ(MOVE_TO(m), 62);
    ASSERT_EQ(MOVE_COLOR(m), BLACK);
    ASSERT_EQ(MOVE_PIECE(m), PAWN);
    ASSERT_EQ(MOVE_PROMOTION_PIECE(m), ROOK);
    ASSERT_FALSE(MOVE_IS_CAPTURE(m));
    ASSERT_FALSE(MOVE_IS_ENPASSANT(m));
    ASSERT_TRUE(MOVE_ISVALID(m));
}

TEST(Check, EmptyBoard) {
    Board board;
    ASSERT_TRUE(board.getOccupancy() > 0);
    ASSERT_FALSE(board.isCheck(Color::WHITE));
    ASSERT_FALSE(board.isCheck(Color::BLACK));
    
    board.clear();
    ASSERT_EQ(board.getOccupancy(), 0);
    ASSERT_FALSE(board.isCheck(Color::WHITE));
    ASSERT_FALSE(board.isCheck(Color::BLACK));
}

TEST(Check, WhiteKingCheckWithKnight) {
    Board board;
    ASSERT_TRUE(FFEN::setFEN("8/2k5/8/8/8/2K5/4n3/8 w - - 0 1", board));
    ASSERT_TRUE(board.isCheck(Color::WHITE));
    ASSERT_FALSE(board.isCheck(Color::BLACK));
}

TEST(Check, WhiteKingCheckWithBishop) {
    Board board;
    ASSERT_TRUE(FFEN::setFEN("8/2k5/5b2/8/8/2K5/8/8 w - - 0 1", board));
    ASSERT_TRUE(board.isCheck(Color::WHITE));
    ASSERT_FALSE(board.isCheck(Color::BLACK));
}

TEST(Check, WhiteKingCheckWithRook) {
    Board board;
    ASSERT_TRUE(FFEN::setFEN("8/2k5/8/8/8/2K3r1/8/8 w - - 0 1", board));
    ASSERT_TRUE(board.isCheck(Color::WHITE));
    ASSERT_FALSE(board.isCheck(Color::BLACK));
}

TEST(Check, WhiteKingCheckWithQueenLikeBishop) {
    Board board;
    ASSERT_TRUE(FFEN::setFEN("8/2k3q1/8/8/8/2K5/8/8 w - - 0 1", board));
    ASSERT_TRUE(board.isCheck(Color::WHITE));
    ASSERT_FALSE(board.isCheck(Color::BLACK));
}

TEST(Check, WhiteKingCheckWithQueenLikeRook) {
    Board board;
    ASSERT_TRUE(FFEN::setFEN("8/2k5/8/8/8/2K3q1/8/8 w - - 0 1", board));
    ASSERT_TRUE(board.isCheck(Color::WHITE));
    ASSERT_FALSE(board.isCheck(Color::BLACK));
}

TEST(Check, WhiteKingNotCheck) {
    Board board;
    ASSERT_TRUE(FFEN::setFEN("8/2k5/8/8/8/2K5/5n2/8 w - - 0 1", board));
    ASSERT_FALSE(board.isCheck(Color::WHITE));
    ASSERT_FALSE(board.isCheck(Color::BLACK));
}

TEST(Check, BlackKingCheck) {
    Board board;
    ASSERT_TRUE(FFEN::setFEN("8/2k5/4N3/8/8/2K5/5n2/8 w - - 0 1", board));
    ASSERT_FALSE(board.isCheck(Color::WHITE));
    ASSERT_TRUE(board.isCheck(Color::BLACK));
}

static void assertBestMove(std::string fen, std::string finalFEN, std::string bestMove, std::vector<std::string> bestLine, int maxDepth = 4) {
    Board board;
    ASSERT_TRUE(FFEN::setFEN(fen, board));
    std::string boardFEN = FFEN::getFEN(board);
    ASSERT_STREQ(boardFEN.c_str(), fen.c_str());
    
    Minimax minimax;
    Minimax::Info info = minimax.searchBestMove(board, maxDepth, nullptr);
    
    // Assert the best move
    auto actualMove = FPGN::to_string(info.evaluation.move);
    ASSERT_STREQ(actualMove.c_str(), bestMove.c_str());
    
    // Assert the best line
    ASSERT_EQ(info.evaluation.line.size(), bestLine.size());

    for (int index=0; index<bestLine.size(); index++) {
        auto lineMove = FPGN::to_string(info.evaluation.line[index]);
        ASSERT_STREQ(lineMove.c_str(), bestLine[index].c_str());
    }
    
    // Now play the moves to reach the final position
    Board finalBoard = board;
    for (auto move : info.evaluation.line) {
        finalBoard.move(move);
    }
    auto finalBoardFEN = FFEN::getFEN(finalBoard);
    ASSERT_STREQ(finalBoardFEN.c_str(), finalFEN.c_str());
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
    assertBestMove(start, end, "c3c4",  { "c3c4", "Qb5xc4", "Nb2xc4", "Kd5xc4" }, 5 );
}

TEST(BestMove, KnightEscapeAttackByPawn) {
    std::string start = "r1bqkbnr/pppp1ppp/2n5/3P4/8/8/PPP2PPP/RNBQKBNR b KQkq - 0 4";
    std::string end = "rnb1kbnr/ppppqppp/B7/3P4/8/4B3/PPP2PPP/RN1QK1NR b KQkq - 4 6";
    // Note: without quiescence search, the engine wants to do Bf8b4 but actually this leads into material loss way down the tree.
    // The best move here is moving the knight out of c6.
    // last move Bf1a6 is pretty bad in the evaluation - why?
    assertBestMove(start, end, "Qd8e7",  { "Qd8e7", "Bc1e3", "Nc6b8", "Bf1a6" }, 5 );
}

// In this situation, we are trying to see if the engine is able to see
// that moving the pawn c2c3 can actually cause a double attacks against black.
TEST(BestMove, MovePawnToAttackBishop) {
    std::string start = "r1bqk1nr/pppp1ppp/2n5/3P4/1b6/8/PPP2PPP/RNBQKBNR w KQkq - 1 5";
    std::string end = "r1bqk1nr/p1pQ1ppp/2p5/b7/8/2P5/PP3PPP/RNB1KBNR b KQkq - 0 7";
    // TODO: note that the last move, Qd1xd7 is not great at all
    assertBestMove(start, end, "c2c3",  { "c2c3", "Bb4a5", "d5xc6", "b7xc6", "Qd1xd7" }, 6);
}

