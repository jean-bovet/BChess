//
//  FTests.hpp
//  BChess
//
//  Created by Jean Bovet on 12/2/17.
//  Copyright © 2017 Jean Bovet. All rights reserved.
//

#include <gtest/gtest.h>

#include "ChessEngine.hpp"
#include "FFEN.hpp"

class EvaluationTests: public ::testing::Test {
public:
    void SetUp() {
        ChessEngine::initialize();
    }
    
    ChessBoard boardFor(std::string fen) {
        ChessBoard board;
        assert(FFEN::setFEN(fen, board));
        return board;
    }
    
    ChessMoveList generateMoves(std::string fen) {
        ChessBoard board;
        assert(FFEN::setFEN(fen, board));
        
        ChessMoveGenerator moveGen;
        auto moveList = moveGen.generateMoves(board, board.color, ChessMoveGenerator::Mode::moveCaptureAndDefenseMoves);
        assert(moveList.count > 0);

        return moveList;
    }
};

TEST_F(EvaluationTests, BonusPosition) {
    ASSERT_EQ(ChessEvaluater::getBonus(PAWN, Color::WHITE, b2), 10);
    ASSERT_EQ(ChessEvaluater::getBonus(PAWN, Color::BLACK, b2), 50);
    
    ASSERT_EQ(ChessEvaluater::getBonus(KNIGHT, Color::BLACK, g8), -40);
    ASSERT_EQ(ChessEvaluater::getBonus(KNIGHT, Color::BLACK, f6), 10);
    
    ASSERT_EQ(ChessEvaluater::getBonus(KNIGHT, Color::BLACK, e7), 5);
    ASSERT_EQ(ChessEvaluater::getBonus(KNIGHT, Color::WHITE, e7), 0);
}

TEST_F(EvaluationTests, InvalidMove) {
    MinMaxMoveList<Move> moveList;
    ASSERT_EQ(INVALID_MOVE, moveList.bestMove());
}

TEST_F(EvaluationTests, WhitePieceMobility) {
    auto board = boardFor("8/8/8/8/8/8/P7/R3K3 w Q - 0 1");
    int value = ChessEvaluater::evaluateMobility(board);
    ASSERT_EQ(12, value); // 10 moves and 1 castling (that count double)
}

TEST_F(EvaluationTests, WhitePieceAction) {
    auto board = boardFor("8/8/8/8/8/8/P7/R3K3 w Q - 0 1");
    int value = ChessEvaluater::evaluateAction(board);
    ASSERT_EQ(2, value);
}

TEST_F(EvaluationTests, BlackPieceMobility) {
    auto board = boardFor("r3k3/p7/8/8/8/8/8/8 b q - 0 1");
    int value = ChessEvaluater::evaluateMobility(board);
    ASSERT_EQ(-12, value); // 10 moves and 1 castling (that count double)
}

TEST_F(EvaluationTests, BlackPieceAction) {
    auto board = boardFor("r3k3/p7/8/8/8/8/8/8 b q - 0 1");
    int value = ChessEvaluater::evaluateAction(board);
    ASSERT_EQ(-2, value);
}

TEST_F(EvaluationTests, EvenAttacks) {
    auto board = boardFor("8/8/8/8/2p5/3P4/8/8 w - - 0 1");
    int value = ChessEvaluater::evaluateAction(board);
    ASSERT_EQ(0, value);
}

TEST_F(EvaluationTests, HangingWhitePiece) {
    auto board = boardFor("8/8/8/4n3/2p5/3P4/8/8 w - - 0 1");
    int value = ChessEvaluater::evaluateAction(board);
    ASSERT_EQ(-12, value);
}
