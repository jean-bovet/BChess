//
//  FTests.hpp
//  BChess
//
//  Created by Jean Bovet on 12/2/17.
//  Copyright © 2017 Jean Bovet. All rights reserved.
//

#include <gtest/gtest.h>

#include "ChessOpenings.hpp"

class OpeningsTests: public ::testing::Test {
public:
    
    ChessOpenings openings;
    
};

TEST_F(OpeningsTests, KingsPawnOpening) {
    Move m;
    ChessMoveList moves;
    moves.push(m = createMove(e2, e4, WHITE, PAWN));
    
    bool result = openings.lookup(moves, [&](auto & node) {
        ASSERT_EQ(m, node.move);
    });
    ASSERT_TRUE(result);
    
    moves.push(m = createMove(e7, e5, BLACK, PAWN));
    result = openings.lookup(moves, [&](auto & node) {
        ASSERT_EQ(m, node.move);
        ASSERT_STREQ("King's pawn game", node.name.c_str());
    });
    ASSERT_TRUE(result);

    moves.push(createMove(e2, e4, WHITE, PAWN));
    result = openings.lookup(moves, [&](auto & node) {
        FAIL();
    });
    ASSERT_FALSE(result);
}

TEST_F(OpeningsTests, BestMove) {
    ChessMoveList moves;
    
    bool result = openings.best(moves, [&](auto & node) {
        ASSERT_EQ(createMove(d2, d4, WHITE, PAWN), node.move);
    });
    ASSERT_TRUE(result);
    
    moves.push(createMove(e2, e4, WHITE, PAWN));
    
    result = openings.best(moves, [&](auto & node) {
        ASSERT_EQ(createMove(e7, e5, BLACK, PAWN), node.move);
    });
    ASSERT_TRUE(result);
}
