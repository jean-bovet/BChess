//
//  FENTests.cpp
//  BChessTests
//

#include <gtest/gtest.h>

#include "ChessBoardHash.hpp"
#include "ChessEngine.hpp"
#include "ChessMoveGenerator.hpp"
#include "FFEN.hpp"

class FEN : public testing::Test {
public:
    void SetUp() {
        ChessEngine::initialize();
    }
};

// A board that is reused must not keep anything from its previous position
TEST_F(FEN, SetFENDoesNotInheritState) {
    ChessBoard reused;
    ASSERT_TRUE(FFEN::setFEN("4k3/8/8/3pP3/8/8/8/4K3 w - d6 0 1", reused));
    
    ASSERT_TRUE(FFEN::setFEN("4k3/8/8/8/8/8/8/R3K2R w KQ e3 5 9", reused));
    Bitboard e3Only = 0;
    bb_set(e3Only, e3);
    ASSERT_EQ(e3Only, reused.enPassant);
    ASSERT_EQ("4k3/8/8/8/8/8/8/R3K2R w KQ e3 5 9", FFEN::getFEN(reused));
    
    // The fields the FEN omits take the values of a new board, minus the rights that cannot exist
    ASSERT_TRUE(FFEN::setFEN("4k3/8/8/8/8/8/8/4K3 b", reused));
    ChessBoard fresh;
    ASSERT_TRUE(FFEN::setFEN("4k3/8/8/8/8/8/8/4K3 b", fresh));
    ASSERT_EQ("4k3/8/8/8/8/8/8/4K3 b - - 0 1", FFEN::getFEN(reused));
    ASSERT_EQ(FFEN::getFEN(fresh), FFEN::getFEN(reused));
    ASSERT_EQ(ChessBoardHash::hash(fresh), reused.getHash());
}

TEST_F(FEN, ImpossibleCastlingRightsAreDropped) {
    ChessBoard board;
    ASSERT_TRUE(FFEN::setFEN("4k3/8/8/8/8/8/8/4K3 w KQkq - 0 1", board));
    ASSERT_EQ("4k3/8/8/8/8/8/8/4K3 w - - 0 1", FFEN::getFEN(board));
    
    MoveList moves = ChessMoveGenerator::generateMoves(board);
    for (int i = 0; i < moves.count; i++) {
        ASSERT_FALSE(MOVE_IS_CASTLING(moves.moves[i]));
    }
    
    // A right whose rook is missing: only the other side stays
    ASSERT_TRUE(FFEN::setFEN("r3k3/8/8/8/8/8/8/4K2R w KQkq - 0 1", board));
    ASSERT_EQ("r3k3/8/8/8/8/8/8/4K2R w Kq - 0 1", FFEN::getFEN(board));
    
    // Possible rights, and the old default for a missing field, are kept
    ASSERT_TRUE(FFEN::setFEN("r3k2r/8/8/8/8/8/8/R3K2R w", board));
    ASSERT_EQ("r3k2r/8/8/8/8/8/8/R3K2R w KQkq - 0 1", FFEN::getFEN(board));
}
