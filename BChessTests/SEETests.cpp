//
//  SEETests.cpp
//  BChessTests
//

#include <gtest/gtest.h>

#include <string>

#include "ChessEngine.hpp"
#include "ChessEvaluater.hpp"
#include "FFEN.hpp"
#include "FPGN.hpp"

class SEETests: public ::testing::Test {
public:
    void SetUp() {
        ChessEngine::initialize();
    }
};

// The legal move that the UCI text spells, in the position
static Move moveIn(ChessBoard &board, const char *uci) {
    Move move = FPGN::uciMove(board, uci);
    EXPECT_TRUE(MOVE_ISVALID(move)) << uci;
    return move;
}

static int seeOf(const char *fen, const char *uci) {
    ChessBoard board;
    EXPECT_TRUE(FFEN::setFEN(fen, board));
    return ChessEvaluater::see(board, moveIn(board, uci));
}

TEST_F(SEETests, PawnTakesKnight) {
    // Undefended: the whole knight
    ASSERT_EQ(320, seeOf("4k3/8/8/3n4/4P3/8/8/4K3 w - - 0 1", "e4d5"));
    // Defended by a pawn, which takes back the pawn: 320 - 100
    ASSERT_EQ(220, seeOf("4k3/8/4p3/3n4/4P3/8/8/4K3 w - - 0 1", "e4d5"));
}

TEST_F(SEETests, QueenTakesDefendedPawn) {
    ASSERT_EQ(-800, seeOf("4k3/8/4p3/3p4/8/8/3Q4/4K3 w - - 0 1", "d2d5"));
}

// The rook behind the one that captures joins the exchange once the first has left the file
TEST_F(SEETests, XRayBattery) {
    // Rxd5 +100, Rxd5 -500, Rxd5 +500, and the second black rook, which stood behind the first, takes the last
    // one: -500. White has lost 100 + 500 - 500 - 500. A SEE that does not look through the rook that left
    // the file stops after the third capture and says +100.
    ASSERT_EQ(-400, seeOf("3rk3/3r4/8/3p4/8/8/3R4/3RK3 w - - 0 1", "d2d5"));
    // Without the rook behind: Rxd5 +100, Rxd5 -500, Rxd5 +500, and the pawn is won
    ASSERT_EQ(100, seeOf("4k3/3r4/8/3p4/8/8/3R4/3RK3 w - - 0 1", "d2d5"));
}

TEST_F(SEETests, EnPassant) {
    ASSERT_EQ(100, seeOf("4k3/8/8/3pP3/8/8/8/4K3 w - d6 0 1", "e5d6"));
}

// Taking the pawn on d5 en passant removes it from the d-file: the rook on d1 then sees d6 and takes the pawn
// back. 100 - 100 = 0. A SEE that leaves the captured pawn on its square thinks it is blocked and says +100.
TEST_F(SEETests, EnPassantOpensALine) {
    ASSERT_EQ(0, seeOf("7k/8/8/3pP3/8/8/6K1/3r4 w - d6 0 1", "e5d6"));
}

TEST_F(SEETests, KingTakesUndefendedPiece) {
    ASSERT_EQ(320, seeOf("4k3/8/8/8/8/3n4/4K3/8 w - - 0 1", "e2d3"));
}

// The only defender is the king, but the second rook still attacks d5 after the first took it, so the king
// cannot take back: the whole knight
TEST_F(SEETests, KingRecaptureIsRefused) {
    ASSERT_EQ(320, seeOf("8/8/4k3/3n4/8/8/3R4/3R2K1 w - - 0 1", "d2d5"));
    // With nothing behind the rook the king does take back: 320 - 500
    ASSERT_EQ(-180, seeOf("8/8/4k3/3n4/8/8/3R4/6K1 w - - 0 1", "d2d5"));
}

// Nb2xd1 (+500), exd1=Q (-320 and a queen for a pawn, -800), Rxd1 (+900), Rxd1 (-500):
// 500 - 1120 + 900 - 500, and the side to move may stop, so what is left is -220. Treating the d1 piece as a
// pawn after the promotion would say +180.
TEST_F(SEETests, RecapturePromotion) {
    ASSERT_EQ(-220, seeOf("3r3k/8/8/8/8/8/1N2p2K/R2r4 w - - 0 1", "b2d1"));
}

// exd8=Q takes a rook and promotes (+500 + 800), Rxd8 (-900), Rxd8 (+500): 1300 - 900 + 500 = 900. Treating the
// pawn as a pawn on d8 would say 500.
TEST_F(SEETests, PromotionCapture) {
    ASSERT_EQ(900, seeOf("r2r3k/4P3/8/8/8/8/8/3R2K1 w - - 0 1", "e7d8q"));
}

// Pins are ignored, as in any usual SEE: the knight on b6 is pinned to its king by the rook on b1 and cannot
// take back on d5, but it counts as a defender, so Rxd5 looks like a rook for a pawn
TEST_F(SEETests, PinsAreIgnored) {
    ASSERT_EQ(-400, seeOf("1k6/8/1n6/3p4/8/8/3R4/1R4K1 w - - 0 1", "d2d5"));
}

// Qxb7 mates (the rook on b8 is pinned by Rh8, the knight guards b7), but SEE counts the pinned rook: Qxb7 +100,
// Rxb7 -900, Nxb7 +500, Kxb7 -320, so the queen looks lost for a pawn and a rook
TEST_F(SEETests, PinnedMateLooksLosing) {
    ASSERT_EQ(-620, seeOf("kr5R/1p6/1Q1N4/8/8/8/8/7K w - - 0 1", "b6b7"));
}
