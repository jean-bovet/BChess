//
//  FTests.hpp
//  BChess
//
//  Created by Jean Bovet on 12/2/17.
//  Copyright © 2017 Jean Bovet. All rights reserved.
//

#include <gtest/gtest.h>

#include "FMove.hpp"

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

TEST(Move, MoveIsCheck) {
    Move m = createMove(12, 62, BLACK, BISHOP);
    ASSERT_FALSE(MOVE_IS_CHECK(m));
    
    SET_MOVE_IS_CHECK(m);
    ASSERT_TRUE(MOVE_IS_CHECK(m));
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

TEST(Move, MoveSetPromotion) {
    Move m = createMove(12, 62, BLACK, BISHOP);
    ASSERT_EQ(MOVE_PROMOTION_PIECE(m), 0);
    
    SET_MOVE_PROMOTION_PIECE(m, QUEEN);
    ASSERT_EQ(MOVE_PROMOTION_PIECE(m), QUEEN);
    
    SET_MOVE_PROMOTION_PIECE(m, KNIGHT);
    ASSERT_EQ(MOVE_PROMOTION_PIECE(m), KNIGHT);
}
