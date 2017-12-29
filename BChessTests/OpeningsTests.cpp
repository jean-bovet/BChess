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
    ChessMoveList moves;
    moves.push(createMove(e2, e4, WHITE, PAWN));

    OpeningTreeNode *node = nullptr;
    
    node = openings.lookup(moves);
    ASSERT_TRUE(node != nullptr);
    
    moves.push(createMove(e7, e5, BLACK, PAWN));
    node = openings.lookup(moves);
    ASSERT_TRUE(node != nullptr);
    ASSERT_STREQ("King's pawn game", node->name.c_str());

    moves.push(createMove(e2, e4, WHITE, PAWN));
    node = openings.lookup(moves);
    ASSERT_TRUE(node == nullptr);
}

TEST_F(OpeningsTests, BestMoveAtStartPosition) {
    ChessMoveList moves;
    moves.push(createMove(e2, e4, WHITE, PAWN));
    
    OpeningTreeNode *node = nullptr;
    
    node = openings.bestMove(moves);
    ASSERT_TRUE(node != nullptr);
    
    moves.push(createMove(e7, e5, BLACK, PAWN));
    node = openings.bestMove(moves);
    ASSERT_TRUE(node != nullptr);
    ASSERT_STREQ("King's pawn game", node->name.c_str());
    
    moves.push(createMove(e2, e4, WHITE, PAWN));
    node = openings.bestMove(moves);
    ASSERT_TRUE(node == nullptr);
}
