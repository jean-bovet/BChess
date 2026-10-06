//
//  PerftTests.cpp
//  BChessTests
//
//  Move generation and ChessBoard::move checked against the published perft counts
//  (https://www.chessprogramming.org/Perft_Results). Every depth is asserted, so a failure names
//  the shallowest wrong depth. The full depths live in planning/assets/ENGINE-1/.
//

#include <gtest/gtest.h>

#include <vector>

#include "ChessEngine.hpp"
#include "ChessMoveGenerator.hpp"
#include "FFEN.hpp"

static uint64_t perft(ChessBoard &board, int depth) {
    MoveList moves = ChessMoveGenerator::generateMoves(board);
    if (depth == 1) {
        return moves.count;
    }
    uint64_t nodes = 0;
    for (int i = 0; i < moves.count; i++) {
        ChessBoard next = board;
        next.move(moves.moves[i]);
        nodes += perft(next, depth - 1);
    }
    return nodes;
}

static void expectPerft(const char *fen, const std::vector<uint64_t> &expected) {
    ChessEngine::initialize();

    ChessBoard board;
    ASSERT_TRUE(FFEN::setFEN(fen, board));
    for (size_t depth = 0; depth < expected.size(); depth++) {
        ASSERT_EQ(perft(board, (int)depth + 1), expected[depth]) << fen << " depth " << depth + 1;
    }
}

// Plays the legal move from -> to, failing the test when there is none
static bool play(ChessBoard &board, Square from, Square to) {
    MoveList moves = ChessMoveGenerator::generateMoves(board);
    for (int i = 0; i < moves.count; i++) {
        if (MOVE_FROM(moves.moves[i]) == from && MOVE_TO(moves.moves[i]) == to) {
            board.move(moves.moves[i]);
            return true;
        }
    }
    return false;
}

static bool canPlay(ChessBoard &board, Square from, Square to) {
    MoveList moves = ChessMoveGenerator::generateMoves(board);
    for (int i = 0; i < moves.count; i++) {
        if (MOVE_FROM(moves.moves[i]) == from && MOVE_TO(moves.moves[i]) == to) {
            return true;
        }
    }
    return false;
}

TEST(Perft, StartPosition) {
    expectPerft("rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1", {20, 400, 8902, 197281});
}

TEST(Perft, Kiwipete) {
    expectPerft("r3k2r/p1ppqpb1/bn2pnp1/3PN3/1p2P3/2N2Q1p/PPPBBPPP/R3K2R w KQkq - 0 1", {48, 2039, 97862, 4085603});
}

TEST(Perft, Position3) {
    expectPerft("8/2p5/3p4/KP5r/1R3p1k/8/4P1P1/8 w - - 0 1", {14, 191, 2812, 43238, 674624});
}

TEST(Perft, Position4) {
    expectPerft("r3k2r/Pppp1ppp/1b3nbN/nP6/BBP1P3/q4N2/Pp1P2PP/R2Q1RK1 w kq - 0 1", {6, 264, 9467, 422333});
}

TEST(Perft, Position5) {
    expectPerft("rnbq1k1r/pp1Pbppp/2p5/8/2B5/8/PPP1NnPP/RNBQK2R w KQ - 1 8", {44, 1486, 62379});
}

TEST(Perft, Position6) {
    expectPerft("r4rk1/1pp1qppp/p1np1n2/2b1p1B1/2B1P1b1/P1NP1N2/1PP1QPPP/R4RK1 w - - 0 10", {46, 2079, 89890});
}

TEST(Perft, CapturedRookLosesCastling) {
    ChessEngine::initialize();

    ChessBoard board;
    ASSERT_TRUE(FFEN::setFEN("4k2r/8/8/8/8/8/8/4K2R w Kk - 0 1", board));
    ASSERT_TRUE(play(board, h1, h8));
    ASSERT_EQ(FFEN::getFEN(board), "4k2R/8/8/8/8/8/8/4K3 b - - 0 1");
}

TEST(Perft, CapturedRookOnH1LosesCastling) {
    ChessEngine::initialize();

    // Position 5: Bxf7+ then Nxh1 captures the rook White still has castling rights for
    ChessBoard board;
    ASSERT_TRUE(FFEN::setFEN("rnbq1k1r/pp1Pbppp/2p5/8/2B5/8/PPP1NnPP/RNBQK2R w KQ - 1 8", board));
    ASSERT_TRUE(play(board, c4, f7));
    ASSERT_TRUE(play(board, f2, h1));
    ASSERT_FALSE(board.whiteCanCastleKingSide);
    ASSERT_FALSE(canPlay(board, e1, g1));
}
