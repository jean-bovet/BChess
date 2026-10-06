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
#include "FUtility.hpp"

class EvaluationTests: public ::testing::Test {
public:
    void SetUp() {
        ChessEngine::initialize();
    }
    
    ChessBoard boardFor(std::string fen) {
        ChessBoard board;
        assert(FFEN::setFEN(fen, board));
        return board;
    }
    
    MoveList generateMoves(std::string fen) {
        ChessBoard board;
        assert(FFEN::setFEN(fen, board));
        
        ChessMoveGenerator moveGen;
        auto moveList = moveGen.generateMoves(board, board.color, ChessMoveGenerator::Mode::moveCaptureAndDefenseMoves);
        assert(moveList.count > 0);

        return moveList;
    }
};

TEST_F(EvaluationTests, BonusPosition) {
    ASSERT_EQ(ChessEvaluater::getBonus(PAWN, Color::WHITE, b2), 10);
    ASSERT_EQ(ChessEvaluater::getBonus(PAWN, Color::BLACK, b2), 50);
    
    ASSERT_EQ(ChessEvaluater::getBonus(KNIGHT, Color::BLACK, g8), -40);
    ASSERT_EQ(ChessEvaluater::getBonus(KNIGHT, Color::BLACK, f6), 10);
    
    ASSERT_EQ(ChessEvaluater::getBonus(KNIGHT, Color::BLACK, e7), 5);
    ASSERT_EQ(ChessEvaluater::getBonus(KNIGHT, Color::WHITE, e7), 0);
}

TEST_F(EvaluationTests, InvalidMove) {
    MoveList moveList;
    ASSERT_EQ(INVALID_MOVE, moveList.bestMove());
}

TEST_F(EvaluationTests, WhitePieceMobility) {
    auto board = boardFor("8/8/8/8/8/8/P7/R3K3 w Q - 0 1");
    int value = ChessEvaluater::evaluateMobility(board);
    ASSERT_EQ(12, value); // 10 moves and 1 castling (that count double)
}

TEST_F(EvaluationTests, WhitePieceAction) {
    auto board = boardFor("8/8/8/8/8/8/P7/R3K3 w Q - 0 1");
    int value = ChessEvaluater::evaluateAction(board);
    ASSERT_EQ(2, value);
}

TEST_F(EvaluationTests, BlackPieceMobility) {
    auto board = boardFor("r3k3/p7/8/8/8/8/8/8 b q - 0 1");
    int value = ChessEvaluater::evaluateMobility(board);
    ASSERT_EQ(-12, value); // 10 moves and 1 castling (that count double)
}

TEST_F(EvaluationTests, BlackPieceAction) {
    auto board = boardFor("r3k3/p7/8/8/8/8/8/8 b q - 0 1");
    int value = ChessEvaluater::evaluateAction(board);
    ASSERT_EQ(-2, value);
}

TEST_F(EvaluationTests, EvenAttacks) {
    auto board = boardFor("8/8/8/8/2p5/3P4/8/8 w - - 0 1");
    int value = ChessEvaluater::evaluateAction(board);
    ASSERT_EQ(0, value);
}

TEST_F(EvaluationTests, HangingWhitePiece) {
    auto board = boardFor("8/8/8/4n3/2p5/3P4/8/8 w - - 0 1");
    int value = ChessEvaluater::evaluateAction(board);
    ASSERT_EQ(-12, value);
}

// Reverses the ranks, swaps the colors, the side to move, the castling rights and the en-passant rank
static std::string mirrorFEN(const std::string &fen) {
    auto swapCase = [](std::string text) {
        for (auto &c : text) {
            c = isupper(c) ? tolower(c) : toupper(c);
        }
        return text;
    };
    
    std::vector<std::string> fields, ranks;
    split4(fen, fields, " ");
    split4(fields[0], ranks, "/");
    
    std::string mirrored;
    for (auto rank = ranks.rbegin(); rank != ranks.rend(); rank++) {
        mirrored += (mirrored.empty() ? "" : "/") + swapCase(*rank);
    }
    
    mirrored += fields[1] == "w" ? " b " : " w ";
    mirrored += fields[2] == "-" ? "-" : swapCase(fields[2]);
    std::string enPassant = fields[3];
    if (enPassant != "-") {
        enPassant[1] = enPassant[1] == '3' ? '6' : '3';
    }
    mirrored += " " + enPassant + " " + fields[4] + " " + fields[5];
    return mirrored;
}

TEST_F(EvaluationTests, MirroredPositionsScoreOpposite) {
    const char *fens[] = {
        "rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1",
        "4k3/8/8/8/8/8/8/2B1KB2 w - - 0 1",
        "2b1kb2/8/8/8/8/8/8/4K3 w - - 0 1",
        "r3k2r/p1ppqpb1/bn2pnp1/3PN3/1p2P3/2N2Q1p/PPPBBPPP/R3K2R w KQkq - 0 1",
        "r3k2r/Pppp1ppp/1b3nbN/nP6/BBP1P3/q4N2/Pp1P2PP/R2Q1RK1 w kq - 0 1",
        "rnbq1k1r/pp1Pbppp/2p5/8/2B5/8/PPP1NnPP/RNBQK2R w KQ - 1 8",
        "r4rk1/1pp1qppp/p1np1n2/2b1p1B1/2B1P1b1/P1NP1N2/1PP1QPPP/R4RK1 w - - 0 10",
    };
    for (auto fen : fens) {
        auto mirror = mirrorFEN(fen);
        ASSERT_EQ(ChessEvaluater::evaluate(boardFor(fen), NEW_HISTORY),
                  -ChessEvaluater::evaluate(boardFor(mirror), NEW_HISTORY)) << fen << " vs " << mirror;
    }
    
    ASSERT_EQ(0, ChessEvaluater::evaluate(boardFor(fens[0]), NEW_HISTORY));
}
