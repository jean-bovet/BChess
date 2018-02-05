//
//  FTests.hpp
//  BChess
//
//  Created by Jean Bovet on 12/2/17.
//  Copyright © 2017 Jean Bovet. All rights reserved.
//

#include <gtest/gtest.h>

#include "ChessBoardHash.hpp"
#include "ChessGame.hpp"
#include "ChessEngine.hpp"

#include "FFEN.hpp"
#include "FPGN.hpp"

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

TEST(BoardHash, EnsureNoCollision) {
    ChessBoardHash::initialize();

    ChessBoard boardA, boardB;
    
    FFEN::setFEN("rnbqkb1r/pppppppp/8/8/6P1/5N2/PPPP1n1P/RNBQKB1R w", boardA);
    FFEN::setFEN("rnbqkb1r/pppppppp/8/8/4P3/5N2/PPPP1n1P/RNBQKB1R w", boardB);

    ASSERT_NE(ChessBoardHash::hash(boardA), ChessBoardHash::hash(boardB));
}

TEST(BoardHash, PlayAndTestForCollision) {
    ChessEngine::initialize();

    ChessGame gameA, gameB;
    
    // Play two different games that end up almost with the same configuration
    // but not exactly. The hash should be different.
    ASSERT_TRUE(FPGN::setGame("1.Nf3 Nf6 2.g4 Nxg4 3.e4 Nxf2", gameA));
    ASSERT_TRUE(FPGN::setGame("1.Nf3 Nf6 2.e4 Nxe4 3.g4 Nxf2", gameB));

    // First, check the short FEN
    ASSERT_STREQ(FFEN::getFEN(gameA.board, true).c_str(), "rnbqkb1r/pppppppp/8/8/4P3/5N2/PPPP1n1P/RNBQKB1R w");
    ASSERT_STREQ(FFEN::getFEN(gameB.board, true).c_str(), "rnbqkb1r/pppppppp/8/8/6P1/5N2/PPPP1n1P/RNBQKB1R w");

    // Check each hash, to make sure the hash from the board has been incrementally updated correctly
    // to be equal to the hash computed with the final board position.
    ASSERT_EQ(gameA.board.getHash(), ChessBoardHash::hash(gameA.board));
    ASSERT_EQ(gameB.board.getHash(), ChessBoardHash::hash(gameB.board));

    // Finally, each hash should be different because the board is different!
    ASSERT_NE(gameA.board.getHash(), gameB.board.getHash());
}
