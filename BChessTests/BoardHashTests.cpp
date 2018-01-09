//
//  FTests.hpp
//  BChess
//
//  Created by Jean Bovet on 12/2/17.
//  Copyright © 2017 Jean Bovet. All rights reserved.
//

#include <gtest/gtest.h>

#include "ChessBoardHash.hpp"

TEST(BoardHash, MakeAndUndoMove) {
    ChessBoardHash::initialize();
    
    ChessBoard board;
    
    auto h1 = board.getHash();
    
    ASSERT_TRUE(h1 > 0);
    
    auto m = createMove(a2, a3, WHITE, PAWN);
    
    board.move(m);
    
    auto h2 = board.getHash();

    ASSERT_TRUE(h2 > 0);

    ASSERT_NE(h1, h2);
    
    board.undo_move(m);
}
