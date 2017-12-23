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

TEST(Check, EmptyBoard) {
    ChessBoard board;
    ASSERT_TRUE(board.getOccupancy() > 0);
    ASSERT_FALSE(board.isCheck(Color::WHITE));
    ASSERT_FALSE(board.isCheck(Color::BLACK));
    
    board.clear();
    ASSERT_EQ(board.getOccupancy(), 0);
    ASSERT_FALSE(board.isCheck(Color::WHITE));
    ASSERT_FALSE(board.isCheck(Color::BLACK));
}

TEST(Check, WhiteKingCheckWithKnight) {
    ChessBoard board;
    ASSERT_TRUE(FFEN::setFEN("8/2k5/8/8/8/2K5/4n3/8 w - - 0 1", board));
    ASSERT_TRUE(board.isCheck(Color::WHITE));
    ASSERT_FALSE(board.isCheck(Color::BLACK));
}

TEST(Check, WhiteKingCheckWithBishop) {
    ChessBoard board;
    ASSERT_TRUE(FFEN::setFEN("8/2k5/5b2/8/8/2K5/8/8 w - - 0 1", board));
    ASSERT_TRUE(board.isCheck(Color::WHITE));
    ASSERT_FALSE(board.isCheck(Color::BLACK));
}

TEST(Check, WhiteKingCheckWithRook) {
    ChessBoard board;
    ASSERT_TRUE(FFEN::setFEN("8/2k5/8/8/8/2K3r1/8/8 w - - 0 1", board));
    ASSERT_TRUE(board.isCheck(Color::WHITE));
    ASSERT_FALSE(board.isCheck(Color::BLACK));
}

TEST(Check, WhiteKingCheckWithQueenLikeBishop) {
    ChessBoard board;
    ASSERT_TRUE(FFEN::setFEN("8/2k3q1/8/8/8/2K5/8/8 w - - 0 1", board));
    ASSERT_TRUE(board.isCheck(Color::WHITE));
    ASSERT_FALSE(board.isCheck(Color::BLACK));
}

TEST(Check, WhiteKingCheckWithQueenLikeRook) {
    ChessBoard board;
    ASSERT_TRUE(FFEN::setFEN("8/2k5/8/8/8/2K3q1/8/8 w - - 0 1", board));
    ASSERT_TRUE(board.isCheck(Color::WHITE));
    ASSERT_FALSE(board.isCheck(Color::BLACK));
}

TEST(Check, WhiteKingNotCheck) {
    ChessBoard board;
    ASSERT_TRUE(FFEN::setFEN("8/2k5/8/8/8/2K5/5n2/8 w - - 0 1", board));
    ASSERT_FALSE(board.isCheck(Color::WHITE));
    ASSERT_FALSE(board.isCheck(Color::BLACK));
}

TEST(Check, BlackKingCheck) {
    ChessBoard board;
    ASSERT_TRUE(FFEN::setFEN("8/2k5/4N3/8/8/2K5/5n2/8 w - - 0 1", board));
    ASSERT_FALSE(board.isCheck(Color::WHITE));
    ASSERT_TRUE(board.isCheck(Color::BLACK));
}
