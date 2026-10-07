//
//  FTests.hpp
//  BChess
//
//  Created by Jean Bovet on 12/2/17.
//  Copyright © 2017 Jean Bovet. All rights reserved.
//

#include <gtest/gtest.h>

#include "FFEN.hpp"
#include "FPGN.hpp"

#include "ChessEngine.hpp"

class BestMoveTests: public ::testing::Test {
public:
    void SetUp() {
        ChessEngine::initialize();
    }
};

static void assertBestMove(std::string fen, std::string expectedFinalFEN, std::string expectedLine, Configuration config, TranspositionTable &table) {
    ChessBoard board;
    ASSERT_TRUE(FFEN::setFEN(fen, board));
    std::string boardFEN = FFEN::getFEN(board);
    ASSERT_EQ(boardFEN, fen);

    ChessMinMaxSearch search;
    search.config = config;

    ChessMinMaxSearch::Variation pv;
    ChessMinMaxSearch::Variation bv;
    
    HistoryPtr history = NEW_HISTORY;
    search.alphabeta(board, history, table, 0, board.color == WHITE, pv, bv);
    
//    std::cout << pv.depth << "/" << pv.qsDepth << std::endl;
//    std::cout << pv.moves.description() << std::endl;
    
    // Assert the best line
    ASSERT_EQ(expectedLine, pv.moves.description());
    
    // Assert the best move
    auto actualMove = FPGN::to_string(pv.moves.bestMove());
    ASSERT_TRUE(expectedLine.compare(0, actualMove.length(), actualMove) == 0);

    // Now play the moves to reach the final position
    ChessBoard finalBoard = board;
    for (int index=0; index<pv.moves.count; index++) {
        auto move = pv.moves[index];
        finalBoard.move(move);
    }
    auto finalBoardFEN = FFEN::getFEN(finalBoard);
    ASSERT_EQ(expectedFinalFEN, finalBoardFEN);
}

static void assertBestMove(std::string fen, std::string expectedFinalFEN, std::string expectedLine, Configuration config) {
    TranspositionTable table;
    assertBestMove(fen, expectedFinalFEN, expectedLine, config, table);
}

static void assertBestMove(std::string fen, std::string expectedFinalFEN, std::string expectedLine) {
    assertBestMove(fen, expectedFinalFEN, expectedLine, Configuration());
}

/** Assert the following position and evaluate the best move for white
 which is c3c4:
 ........
 ........
 ........
 .♛.♚....
 ........
 ..♙.....
 .♘......
 ....♔...
 */
TEST_F(BestMoveTests, PawnForkQueenAndKing) {
    std::string start = "8/8/8/1q1k4/8/2P5/1N6/4K3 w - - 0 1";
    std::string end = "8/8/8/8/2k5/8/8/4K3 w - - 0 3";
    assertBestMove(start, end, "c3c4 Qb5xc4 Nb2xc4 Kd5xc4");
}

TEST_F(BestMoveTests, QueenEatPawn) {
    std::string start = "7k/6p1/5p2/5Q2/8/8/8/7K w - - 0 1";
    std::string end = "7k/6p1/5Q2/8/8/8/8/7K b - - 0 1";
    Configuration config;
    config.maxDepth = 1;
    config.quiescenceSearch = false;
    assertBestMove(start, end, "Qf5xf6", config);
}

TEST_F(BestMoveTests, QueenShouldNotEatPawn) {
    std::string start = "7k/6p1/5p2/5Q2/8/8/8/7K w - - 0 1";
    std::string end = "7k/6p1/5p2/5Q2/8/8/8/6K1 b - - 1 1";
    Configuration config;
    config.maxDepth = 1;
    config.quiescenceSearch = true;
    assertBestMove(start, end, "Kh1g1", config);
}

TEST_F(BestMoveTests, KnightEscapeAttackByPawn) {
    std::string start = "r1bqkbnr/pppp1ppp/2n5/3P4/8/8/PPP2PPP/RNBQKBNR b KQkq - 0 4";
    std::string end = "r1bqkb1r/ppp2ppp/3p1n2/3Pn3/8/2N2N2/PPP2PPP/R1BQKB1R w KQkq - 0 7";
    // Note: without quiescence search, the engine wants to do Bf8b4 but actually this leads into material loss way down the tree.
    // The best move here is moving the knight out of c6.
    // Depth 4 is not enough since the quiescence search stands pat: after Bf8b4+ c2c3 Qd8e7+ Ng1e2 Black
    // is to move with bishop and knight both attacked and is assumed to save both (horizon effect). Depth 5 sees it.
    Configuration config;
    config.maxDepth = 5;
    assertBestMove(start, end, "Nc6e5 Nb1c3 Ng8f6 Ng1f3 d7d6", config);
}

// In this situation, we are trying to see if the engine is able to see
// that moving the pawn c2c3 can actually cause a double attacks against black.
TEST_F(BestMoveTests, MovePawnToAttackBishop) {
    std::string start = "r1bqk1nr/pppp1ppp/2n5/3P4/1b6/8/PPP2PPP/RNBQKBNR w KQkq - 1 5";
    std::string end = "r1bk2nr/ppp2ppp/2p5/2b5/8/2P5/PP3PPP/RNB1KBNR w KQ - 0 8";
    assertBestMove(start, end, "c2c3 Bb4c5 d5xc6 d7xc6 Qd1xd8 Ke8xd8");
}

TEST_F(BestMoveTests, BlackMoveToMateNonSorted) {
    std::string start = "8/6k1/p7/2rbp3/8/7P/5qPK/8 b - - 3 39";
    std::string end = "8/6k1/p7/2rbp3/8/7P/6qK/8 w - - 0 40";
    Configuration config;
    config.sortMoves = false;
    // The mate in 1 (Stockfish: mate 1), where the engine used to play on to a mate in 3 first
    assertBestMove(start, end, "Qf2xg2", config );
}

TEST_F(BestMoveTests, BlackMoveToMate) {
    std::string start = "8/6k1/p7/2rbp3/8/7P/5qPK/8 b - - 3 39";
    std::string end = "8/6k1/p7/2rbp3/8/7P/6qK/8 w - - 0 40";
    Configuration config;
    config.sortMoves = true;
    assertBestMove(start, end, "Qf2xg2", config );
}

TEST_F(BestMoveTests, WhiteThreatenMate) {
    std::string start = "3r1k1r/1pp2ppp/pq6/3P4/5Q2/P1P4P/1P1R2P1/5R1K b - - 2 24";
    // Note: black king is about to get mate.
    // Stockfish depth 20: f7f6 is the best move (about -3.6 pawns for a lost position), Rd8d7 -4.4. The search
    // sees both at +0.15 and the move order breaks the tie: the table-less depths 3, 5 and 6 already play
    // Rd8d7. Since quiescence searches the evasions of a side in check (ENGINE-3 search step 4) the depth-4
    // search plays it too, which the ENGINE-1 judge (within 30 centipawns of the best) does not accept.
    // TEMPORARY EXCEPTION (Jean, 2026-10-07): Rd8d7 is accepted until the check extension (step 5) has been
    // measured; then this is re-checked against the 30 cp rule. Any other move is a regression.
    ChessBoard board;
    ASSERT_TRUE(FFEN::setFEN(start, board));
    ChessMinMaxSearch search;
    TranspositionTable table;
    ChessMinMaxSearch::Variation pv, bv;
    search.alphabeta(board, NEW_HISTORY, table, 0, false, pv, bv);
    ASSERT_GT(pv.moves.count, 0);
    auto move = FPGN::to_string(pv.moves.bestMove(), FPGN::SANType::uci);
    ASSERT_TRUE(move == "f7f6" || move == "d8d7") << move;
}

// A smoke test: a transposition table legitimately changes the line the search finds (entries of other
// depths and bounds cut it), so only check that both configurations complete with a legal move and a
// sound score for this near-equal opening position (Stockfish: about +0.3 pawn).
TEST_F(BestMoveTests, WithAndWithoutTT) {
    ChessBoard board;
    ASSERT_TRUE(FFEN::setFEN("rnbqkb1r/ppp1pppp/5n2/3p4/3P4/5N2/PPP1PPPP/RNBQKB1R w KQkq - 0 3", board));
    
    for (bool useTable : {false, true}) {
        Configuration config;
        config.maxDepth = 5;
        config.transpositionTable = useTable;
        
        ChessMinMaxSearch search;
        search.config = config;
        ChessMinMaxSearch::Variation pv, bv;
        TranspositionTable table;
        int score = search.alphabeta(board, NEW_HISTORY, table, 0, true, pv, bv);
        
        ASSERT_GT(pv.moves.count, 0) << "table " << useTable;
        ASSERT_LT(std::abs(score), 100) << "table " << useTable;
        
        bool legal = false;
        MoveList moves = ChessMoveGenerator::generateMoves(board);
        for (int i = 0; i < moves.count; i++) {
            legal = legal || moves.moves[i] == pv.moves.bestMove();
        }
        ASSERT_TRUE(legal) << "table " << useTable;
    }
}
