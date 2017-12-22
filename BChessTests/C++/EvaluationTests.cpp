//
//  FTests.hpp
//  BChess
//
//  Created by Jean Bovet on 12/2/17.
//  Copyright © 2017 Jean Bovet. All rights reserved.
//

#include <gtest/gtest.h>

#include "FEvaluate.hpp"

TEST(Evaluation, BonusPosition) {
    ASSERT_EQ(ChessEvaluate::getBonus(PAWN, Color::WHITE, b2), 10);
    ASSERT_EQ(ChessEvaluate::getBonus(PAWN, Color::BLACK, b2), 50);
}

