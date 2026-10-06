//
//  FENTests.cpp
//  BChessTests
//

#include <gtest/gtest.h>

#include <climits>
#include <string>

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
    
    ASSERT_TRUE(FFEN::setFEN("4k3/8/8/8/3Pp3/8/8/R3K2R b KQ d3 5 9", reused));
    Bitboard d3Only = 0;
    bb_set(d3Only, d3);
    ASSERT_EQ(d3Only, reused.enPassant);
    ASSERT_EQ("4k3/8/8/8/3Pp3/8/8/R3K2R b KQ d3 5 9", FFEN::getFEN(reused));
    
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
    
    // Kings off their home squares: no right at all
    ASSERT_TRUE(FFEN::setFEN("r2k3r/8/8/8/8/8/8/R2K3R w KQkq - 0 1", board));
    ASSERT_EQ("r2k3r/8/8/8/8/8/8/R2K3R w - - 0 1", FFEN::getFEN(board));
    
    // Possible rights, and the old default for a missing field, are kept
    ASSERT_TRUE(FFEN::setFEN("r3k2r/8/8/8/8/8/8/R3K2R w", board));
    ASSERT_EQ("r3k2r/8/8/8/8/8/8/R3K2R w KQkq - 0 1", FFEN::getFEN(board));
}

// Files keep opening: an en-passant square that cannot be captured is dropped, not rejected
TEST_F(FEN, ImpossibleEnPassantSquareIsDropped) {
    ChessBoard board;
    // No pawn behind the target, occupied target, wrong rank for the side to move
    for (auto fen : {"4k3/8/8/4P3/8/8/8/4K3 w - d6 0 1", "4k3/8/3n4/3pP3/8/8/8/4K3 w - d6 0 1", "4k3/8/8/3pP3/8/8/8/4K3 w - d3 0 1"}) {
        ASSERT_TRUE(FFEN::setFEN(fen, board)) << fen;
        ASSERT_EQ(0u, board.enPassant) << fen;
    }
    
    // A real one stays
    ASSERT_TRUE(FFEN::setFEN("4k3/8/8/3pP3/8/8/8/4K3 w - d6 0 1", board));
    ASSERT_NE(0u, board.enPassant);
}

// Input that writes outside the board, or that is not a position, is refused and leaves the board as it was
TEST_F(FEN, RejectsOnlyUnsafe) {
    ChessBoard board;
    ASSERT_TRUE(FFEN::setFEN("r3k2r/8/8/8/8/8/8/R3K2R b KQkq - 3 7", board));
    std::string before = FFEN::getFEN(board);
    auto hash = board.getHash();
    
    for (auto fen : {
        "4k3/8/8/8/8/8/8/4X3 w - - 0 1",                // an unknown piece letter, after a half-filled board
        "rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNX w KQkq - 0 1",
        "4k3",                                          // no side to move
    }) {
        ASSERT_FALSE(FFEN::setFEN(fen, board)) << fen;
        ASSERT_EQ(before, FFEN::getFEN(board)) << fen;
        ASSERT_EQ(hash, board.getHash()) << fen;
    }
}

// Everything an earlier version accepted still loads, with the unsafe values neutralised
TEST_F(FEN, SanitizesLegacy) {
    ChessBoard board;
    
    // Unknown and impossible en passant squares
    ASSERT_TRUE(FFEN::setFEN("4k3/8/8/8/8/8/8/4K3 w - z9 0 1", board));
    ASSERT_EQ("4k3/8/8/8/8/8/8/4K3 w - - 0 1", FFEN::getFEN(board));
    ASSERT_TRUE(FFEN::setFEN("4k3/8/8/8/8/8/8/4K3 w - e4 0 1", board));
    ASSERT_EQ("4k3/8/8/8/8/8/8/4K3 w - - 0 1", FFEN::getFEN(board));
    ASSERT_TRUE(FFEN::setFEN("4k3/8/8/8/8/8/8/4K3 w - 99 0 1", board));
    ASSERT_EQ("4k3/8/8/8/8/8/8/4K3 w - - 0 1", FFEN::getFEN(board));
    
    // Castling letters that mean nothing
    ASSERT_TRUE(FFEN::setFEN("r3k2r/8/8/8/8/8/8/R3K2R w KXq - 0 1", board));
    ASSERT_EQ("r3k2r/8/8/8/8/8/8/R3K2R w Kq - 0 1", FFEN::getFEN(board));
    
    // Empty squares past the end of a rank, and an empty 9th rank, did no harm and still load
    ASSERT_TRUE(FFEN::setFEN("4k4/8/8/8/8/8/8/4K3 w - - 0 1", board));
    ASSERT_EQ("4k3/8/8/8/8/8/8/4K3 w - - 0 1", FFEN::getFEN(board));
    ASSERT_TRUE(FFEN::setFEN("4k3/8/8/8/8/8/8/4K3/8 w - - 0 1", board));
    ASSERT_EQ("4k3/8/8/8/8/8/8/4K3 w - - 0 1", FFEN::getFEN(board));
    // A piece that is off the board is ignored (earlier versions did the same)
    ASSERT_TRUE(FFEN::setFEN("4k3k/8/8/8/8/8/8/4K3 w - - 0 1", board));
    ASSERT_EQ("4k3/8/8/8/8/8/8/4K3 w - - 0 1", FFEN::getFEN(board));
    ASSERT_TRUE(FFEN::setFEN("4k3/8/8/8/8/8/8/4K3/4K3 w - - 0 1", board));
    ASSERT_EQ("4k3/8/8/8/8/8/8/4K3 w - - 0 1", FFEN::getFEN(board));
    ASSERT_TRUE(FFEN::setFEN("4k9/8/8/8/8/8/8/4K3 w - - 0 1", board) == false); // 9 is not a count
    
    // Short ranks: the missing squares are empty
    ASSERT_TRUE(FFEN::setFEN("4k3/8/8/8/8/8/8/4K2 w - - 0 1", board));
    ASSERT_EQ("4k3/8/8/8/8/8/8/4K3 w - - 0 1", FFEN::getFEN(board));
    ASSERT_TRUE(FFEN::setFEN("4k3/8/8/8/8/8/8/4K3 w - - 0 1", board));
    
    // Fewer than 8 ranks
    ASSERT_TRUE(FFEN::setFEN("4k3/8/8/8/8 w - - 0 1", board));
    ASSERT_EQ("4k3/8/8/8/8/8/8/8 w - - 0 1", FFEN::getFEN(board));
    
    // A side to move other than "w" means Black
    ASSERT_TRUE(FFEN::setFEN("4k3/8/8/8/8/8/8/4K3 x", board));
    ASSERT_EQ(BLACK, board.color);
    
    // EPD
    ASSERT_TRUE(FFEN::setFEN("1rbq1rk1/p1b1nppp/1p2p3/8/1B1pN3/P2B4/1P3PPP/2RQ1R1K w - - bm Nf6+; id \"position 01\";", board));
    ASSERT_EQ(0u, FFEN::getFEN(board).find("1rbq1rk1/p1b1nppp/1p2p3/8/1B1pN3/P2B4/1P3PPP/2RQ1R1K w - - "));
    
    // A valid position round-trips unchanged
    for (auto fen : {
        "rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1",
        "r3k2r/p1ppqpb1/bn2pnp1/3PN3/1p2P3/2N2Q1p/PPPBBPPP/R3K2R w KQkq - 0 1",
        "8/2p5/3p4/KP5r/1R3p1k/8/4P1P1/8 w - - 0 1",
        "r3k2r/Pppp1ppp/1b3nbN/nP6/BBP1P3/q4N2/Pp1P2PP/R2Q1RK1 w kq - 0 1",
        "rnbq1k1r/pp1Pbppp/2p5/8/2B5/8/PPP1NnPP/RNBQK2R w KQ - 1 8",
        "r4rk1/1pp1qppp/p1np1n2/2b1p1B1/2B1P1b1/P1NP1N2/1PP1QPPP/R4RK1 w - - 0 10",
        "4k3/8/8/3pP3/8/8/8/4K3 w - d6 0 1",
    }) {
        ASSERT_TRUE(FFEN::setFEN(fen, board)) << fen;
        ASSERT_EQ(fen, FFEN::getFEN(board));
    }
}

// The file counter of earlier versions was an unsigned byte that wrapped: 32 times "8" put the king of the
// next group on the first file. Such text may be in a saved file, so it keeps its meaning.
TEST_F(FEN, FileCounterWrapsLikeBefore) {
    ChessBoard board;
    ASSERT_TRUE(FFEN::setFEN(std::string(32, '8') + "k7/8/8/8/8/8/8/4K3 b - - 0 1", board));
    ASSERT_EQ("k7/8/8/8/8/8/8/4K3 b - - 0 1", FFEN::getFEN(board));
    
    // Off the board before the wrap: ignored, as before
    ASSERT_TRUE(FFEN::setFEN("4k3/8/8/8/8/8/8/4K3/" + std::string(30, '8') + "k7 b - - 0 1", board));
    ASSERT_EQ("4k3/8/8/8/8/8/8/4K3 b - - 0 1", FFEN::getFEN(board));
}

// Counters that a FEN carries must not overflow when moves are generated or played
TEST_F(FEN, HugeCountersSaturate) {
    ChessBoard board;
    ASSERT_TRUE(FFEN::setFEN("4k3/8/8/8/8/8/8/4K3 b - - 2147483647 2147483647", board));
    ASSERT_EQ("4k3/8/8/8/8/8/8/4K3 b - - 2147483647 2147483647", FFEN::getFEN(board));
    
    MoveList moves = ChessMoveGenerator::generateMoves(board);
    ASSERT_GT(moves.count, 0);
    for (int i = 0; i < moves.count; i++) {
        ChessBoard next = board;
        next.move(moves.moves[i]);
        ASSERT_EQ(INT_MAX, next.halfMoveClock);
        ASSERT_EQ(INT_MAX, next.fullMoveCount);
    }
}
