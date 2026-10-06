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
#include "ChessMoveGenerator.hpp"

TEST(BoardHash, MakeAndUndoMove) {
    ChessEngine::initialize();
    
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
    ChessEngine::initialize();

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
    ASSERT_EQ(FFEN::getFEN(gameA.board, true), "rnbqkb1r/pppppppp/8/8/4P3/5N2/PPPP1n1P/RNBQKB1R w");
    ASSERT_EQ(FFEN::getFEN(gameB.board, true), "rnbqkb1r/pppppppp/8/8/6P1/5N2/PPPP1n1P/RNBQKB1R w");

    // Check each hash, to make sure the hash from the board has been incrementally updated correctly
    // to be equal to the hash computed with the final board position.
    ASSERT_EQ(gameA.board.getHash(), ChessBoardHash::hash(gameA.board));
    ASSERT_EQ(gameB.board.getHash(), ChessBoardHash::hash(gameB.board));

    // Finally, each hash should be different because the board is different!
    ASSERT_NE(gameA.board.getHash(), gameB.board.getHash());
}

TEST(BoardHash, EnPassantKeepsHashExact) {
    ChessEngine::initialize();

    ChessBoard board;
    ASSERT_TRUE(FFEN::setFEN("4k3/8/8/3pP3/8/8/8/4K3 w - d6 0 1", board));
    board.move(createEnPassant(e5, d6, WHITE, PAWN));

    ASSERT_EQ(FFEN::getFEN(board), "4k3/8/3P4/8/8/8/8/4K3 b - - 0 1");
    ASSERT_EQ(board.getHash(), ChessBoardHash::hash(board));
}

static BoardHash hashOfFEN(const char *fen) {
    ChessBoard board;
    EXPECT_TRUE(FFEN::setFEN(fen, board));
    return ChessBoardHash::hash(board);
}

// Plays the legal en-passant capture of the position and checks the incremental hash against the one
// computed from scratch
static void expectEnPassantHashExact(const char *fen) {
    ChessBoard board;
    ASSERT_TRUE(FFEN::setFEN(fen, board));
    MoveList moves = ChessMoveGenerator::generateMoves(board);
    for (int i = 0; i < moves.count; i++) {
        if (MOVE_IS_ENPASSANT(moves.moves[i])) {
            ChessBoard next = board;
            next.move(moves.moves[i]);
            ASSERT_EQ(next.getHash(), ChessBoardHash::hash(next)) << fen;
            return;
        }
    }
    FAIL() << "no en-passant capture in " << fen;
}

TEST(BoardHash, CastlingAndEnPassantChangeTheHash) {
    ChessEngine::initialize();

    ASSERT_NE(hashOfFEN("r3k2r/8/8/8/8/8/8/R3K2R w KQkq - 0 1"), hashOfFEN("r3k2r/8/8/8/8/8/8/R3K2R w Kkq - 0 1"));
    ASSERT_NE(hashOfFEN("4k3/8/8/3pP3/8/8/8/4K3 w - d6 0 1"), hashOfFEN("4k3/8/8/3pP3/8/8/8/4K3 w - - 0 1"));
    
    // After 1. e4 no black pawn can take en passant, so the e3 square does not count
    ASSERT_EQ(hashOfFEN("rnbqkbnr/pppppppp/8/8/4P3/8/PPPP1PPP/RNBQKBNR b KQkq e3 0 1"),
              hashOfFEN("rnbqkbnr/pppppppp/8/8/4P3/8/PPPP1PPP/RNBQKBNR b KQkq - 0 1"));
}

// Expectations come from python-chess has_legal_en_passant()
TEST(BoardHash, EnPassantInTheHashOnlyWhenLegal) {
    ChessEngine::initialize();

    struct Case { const char *withEnPassant; const char *without; bool legal; };
    const Case cases[] = {
        // Black to move, exd3 legal
        {"4k3/8/8/8/3Pp3/8/8/4K3 b - d3 0 1", "4k3/8/8/8/3Pp3/8/8/4K3 b - - 0 1", true},
        // exd3 opens the e-file to the rook
        {"4k3/8/8/8/3Pp3/8/8/K3R3 b - d3 0 1", "4k3/8/8/8/3Pp3/8/8/K3R3 b - - 0 1", false},
        // both pawns leave rank 4, the rook sees the king
        {"4K3/8/8/8/k2Pp2R/8/8/8 b - d3 0 1", "4K3/8/8/8/k2Pp2R/8/8/8 b - - 0 1", false},
        // two candidates: e5 is pinned, c5 can take
        {"4k3/6b1/8/2PpP3/8/2K5/8/8 w - d6 0 1", "4k3/6b1/8/2PpP3/8/2K5/8/8 w - - 0 1", true},
        // two candidates for Black: e4 is pinned, c4 can take
        {"8/8/2k5/8/2pPp3/8/6B1/4K3 b - d3 0 1", "8/8/2k5/8/2pPp3/8/6B1/4K3 b - - 0 1", true},
    };
    for (auto &c : cases) {
        if (c.legal) {
            ASSERT_NE(hashOfFEN(c.withEnPassant), hashOfFEN(c.without)) << c.withEnPassant;
            expectEnPassantHashExact(c.withEnPassant);
        } else {
            ASSERT_EQ(hashOfFEN(c.withEnPassant), hashOfFEN(c.without)) << c.withEnPassant;
        }
    }
}

// A pawn attacks the en-passant square in each case, but the capture would leave the king in check
TEST(BoardHash, IllegalEnPassantIsNotInTheHash) {
    ChessEngine::initialize();

    ASSERT_EQ(hashOfFEN("k3r3/8/8/3pP3/8/8/8/4K3 w - d6 0 1"), hashOfFEN("k3r3/8/8/3pP3/8/8/8/4K3 w - - 0 1"));
    ASSERT_EQ(hashOfFEN("8/8/8/K2pP2r/8/8/8/4k3 w - d6 0 1"), hashOfFEN("8/8/8/K2pP2r/8/8/8/4k3 w - - 0 1"));
    ASSERT_EQ(hashOfFEN("4k3/6b1/8/3pP3/8/2K5/8/8 w - d6 0 1"), hashOfFEN("4k3/6b1/8/3pP3/8/2K5/8/8 w - - 0 1"));
}

TEST(BoardHash, StateKeysAreMaintainedIncrementally) {
    ChessEngine::initialize();

    // Double push that allows the capture, the capture, and a rook move that loses a right
    ChessGame game;
    ASSERT_TRUE(FPGN::setGame("1. e4 a6 2. e5 d5 3. exd6 Nf6 4. Nf3 Nc6 5. Rg1 *", game));
    ASSERT_EQ(game.board.getHash(), ChessBoardHash::hash(game.board));
}
