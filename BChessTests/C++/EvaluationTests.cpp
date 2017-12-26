//
//  FTests.hpp
//  BChess
//
//  Created by Jean Bovet on 12/2/17.
//  Copyright © 2017 Jean Bovet. All rights reserved.
//

#include <gtest/gtest.h>

#include "ChessEngine.hpp"

TEST(Evaluation, BonusPosition) {
    ASSERT_EQ(ChessEvaluater::getBonus(PAWN, Color::WHITE, b2), 10);
    ASSERT_EQ(ChessEvaluater::getBonus(PAWN, Color::BLACK, b2), 50);
}

TEST(Evaluation, InvalidMove) {
    MinMaxMoveList<Move> moveList;
    ASSERT_EQ(INVALID_MOVE, moveList.bestMove());
}
