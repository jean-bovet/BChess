//
//  ChessGameTests.cpp
//  BChessTests
//
//  Navigation inside the tree of moves: the move path stays a root-to-leaf path, the board and the
//  repetition history follow the cursor.
//

#include <gtest/gtest.h>

#include "ChessEngine.hpp"
#include "ChessEvaluater.hpp"
#include "FPGN.hpp"

#include <string>
#include <vector>

class ChessGameTests: public ::testing::Test {
public:
    void SetUp() {
        ChessEngine::initialize();
    }
};

// The FEN of the start position after the given UCI moves.
static std::string fenAfter(std::vector<std::string> moves) {
    ChessGame game;
    for (auto & m : moves) {
        EXPECT_TRUE(game.move(m)) << m;
    }
    return game.getFEN();
}

// The uuid of the node reached from the root by the given UCI moves.
static unsigned int uuidAt(ChessGame & game, std::vector<std::string> moves) {
    ChessGame::MoveNode root = game.getRoot();
    ChessGame::MoveNode *node = &root;
    for (auto & m : moves) {
        ChessGame::MoveNode *next = nullptr;
        for (auto & child : node->variations) {
            if (FPGN::to_string(child.move, FPGN::SANType::uci) == m) {
                next = &child;
                break;
            }
        }
        EXPECT_TRUE(next != nullptr) << "no move " << m;
        if (next == nullptr) {
            return 0;
        }
        node = next;
    }
    return node->uuid;
}

static ChessGame gameFromPGN(std::string pgn) {
    ChessGame game;
    EXPECT_TRUE(FPGN::setGame(pgn, game));
    return game;
}

TEST_F(ChessGameTests, SetCurrentMoveUUIDReplaysBoard) {
    auto game = gameFromPGN("1. e4 e5 2. Nf3 *");
    game.setCurrentMoveUUID(uuidAt(game, {"e2e4"}));
    
    ASSERT_EQ(fenAfter({"e2e4"}), game.getFEN());
    ASSERT_EQ(BLACK, game.board.color);
    ASSERT_EQ(1, game.getNumberOfMoves());
    ASSERT_EQ(2u, game.history->size()); // the initial position and the position after 1. e4
}

TEST_F(ChessGameTests, SetCurrentMoveUUIDAcrossBranches) {
    auto game = gameFromPGN("1. e4 e5 (1... c5 2. Nf3) 2. Nf3 *");
    game.setCurrentMoveUUID(uuidAt(game, {"e2e4", "c7c5"}));
    
    ASSERT_EQ(fenAfter({"e2e4", "c7c5"}), game.getFEN());
    
    // Forward navigation continues on that branch
    ASSERT_TRUE(game.canMoveTo(ChessGame::Direction::forward));
    game.moveTo(ChessGame::Direction::forward, 0);
    ASSERT_EQ(fenAfter({"e2e4", "c7c5", "g1f3"}), game.getFEN());
}

TEST_F(ChessGameTests, UnknownUUIDDoesNothing) {
    auto game = gameFromPGN("1. e4 e5 *");
    auto fen = game.getFEN();
    game.setCurrentMoveUUID(99999);
    ASSERT_EQ(fen, game.getFEN());
    ASSERT_EQ(2, game.getNumberOfMoves());
}

// The branch (4 moves) is longer than the main line (2 moves).
TEST_F(ChessGameTests, BackwardKeepsLongerBranch) {
    auto game = gameFromPGN("1. e4 e5 (1... c5 2. Nf3 d6) *");
    game.setCurrentMoveUUID(uuidAt(game, {"e2e4", "c7c5", "g1f3", "d7d6"}));
    ASSERT_EQ(fenAfter({"e2e4", "c7c5", "g1f3", "d7d6"}), game.getFEN());

    game.moveTo(ChessGame::Direction::backward, 0);
    ASSERT_EQ(fenAfter({"e2e4", "c7c5", "g1f3"}), game.getFEN());
    
    game.moveTo(ChessGame::Direction::start, 0);
    ASSERT_EQ(fenAfter({}), game.getFEN());
    
    game.moveTo(ChessGame::Direction::end, 0);
    ASSERT_EQ(fenAfter({"e2e4", "c7c5", "g1f3", "d7d6"}), game.getFEN());
}

TEST_F(ChessGameTests, ForwardOntoShorterBranchDropsStaleTail) {
    auto game = gameFromPGN("1. e4 e5 (1... c5 2. Nf3 d6) *");
    game.setCurrentMoveUUID(uuidAt(game, {"e2e4", "c7c5", "g1f3", "d7d6"}));
    
    // Back to after 1. e4, then forward onto the shorter main line
    game.moveTo(ChessGame::Direction::backward, 0);
    game.moveTo(ChessGame::Direction::backward, 0);
    game.moveTo(ChessGame::Direction::backward, 0);
    ASSERT_EQ(fenAfter({"e2e4"}), game.getFEN());
    game.moveTo(ChessGame::Direction::forward, 0);
    ASSERT_EQ(fenAfter({"e2e4", "e7e5"}), game.getFEN());
    ASSERT_FALSE(game.canMoveTo(ChessGame::Direction::forward));
    ASSERT_FALSE(game.canMoveTo(ChessGame::Direction::end));
    
    // The reverse lengths: the branch is the shorter one
    auto other = gameFromPGN("1. e4 c5 (1... e5) 2. Nf3 d6 *");
    other.setCurrentMoveUUID(uuidAt(other, {"e2e4", "e7e5"}));
    other.moveTo(ChessGame::Direction::start, 0);
    other.moveTo(ChessGame::Direction::end, 0);
    ASSERT_EQ(fenAfter({"e2e4", "e7e5"}), other.getFEN());
    
    other.moveTo(ChessGame::Direction::backward, 0);
    ASSERT_TRUE(other.canMoveTo(ChessGame::Direction::forward));
    other.moveTo(ChessGame::Direction::forward, 0);
    ASSERT_TRUE(other.canMoveTo(ChessGame::Direction::forward));
    other.moveTo(ChessGame::Direction::end, 0);
    ASSERT_EQ(fenAfter({"e2e4", "c7c5", "g1f3", "d7d6"}), other.getFEN());
}

TEST_F(ChessGameTests, MoveMidLineDropsStaleTail) {
    auto game = gameFromPGN("1. e4 e5 2. Nf3 *");
    game.moveTo(ChessGame::Direction::backward, 0);
    game.moveTo(ChessGame::Direction::backward, 0);
    ASSERT_EQ(fenAfter({"e2e4"}), game.getFEN());
    
    // A new variation: nothing follows it
    ASSERT_TRUE(game.move("c7c5"));
    ASSERT_EQ(fenAfter({"e2e4", "c7c5"}), game.getFEN());
    ASSERT_FALSE(game.canMoveTo(ChessGame::Direction::forward));
    ASSERT_EQ(2, game.getNumberOfMoves());
}

TEST_F(ChessGameTests, MoveMidLineOntoExistingNodeContinuesMainLine) {
    auto game = gameFromPGN("1. e4 e5 2. Nf3 *");
    game.moveTo(ChessGame::Direction::start, 0);
    ASSERT_TRUE(game.move("e2e4"));
    ASSERT_EQ(1, game.getNumberOfMoves());
    ASSERT_TRUE(game.canMoveTo(ChessGame::Direction::end));
    game.moveTo(ChessGame::Direction::end, 0);
    ASSERT_EQ(fenAfter({"e2e4", "e7e5", "g1f3"}), game.getFEN());
}

TEST_F(ChessGameTests, NavigationRebuildsHistory) {
    auto game = gameFromPGN("1. Nf3 Nf6 2. Ng1 Ng8 3. Nf3 Nf6 4. Ng1 Ng8 5. Nf3 Nf6 *");
    
    // The position after Black's knight returns to f6 occurred after plies 2, 6 and 10.
    ASSERT_EQ(10, game.getNumberOfMoves());
    ASSERT_TRUE(ChessEvaluater::isDraw(game.board, game.history));
    
    for (int step=0; step<4; step++) {
        game.moveTo(ChessGame::Direction::backward, 0);
    }
    ASSERT_EQ(7u, game.history->size());
    ASSERT_FALSE(ChessEvaluater::isDraw(game.board, game.history));
}

// The hash is updated incrementally while a game is replayed: it must start from the exact hash of the
// initial position, otherwise the history holds positions that never compare equal to the same position
// reached another way.
TEST_F(ChessGameTests, ReplayedHistoryMatchesPlayedHistory) {
    ChessGame game;
    for (auto & m : std::vector<std::string> { "g1f3", "g8f6", "f3g1", "f6g8", "g1f3" }) {
        ASSERT_TRUE(game.move(m)) << m;
    }
    auto played = *game.history;
    ASSERT_EQ(6u, played.size()); // the initial position and 5 moves
    
    game.moveTo(ChessGame::Direction::start, 0);
    game.moveTo(ChessGame::Direction::end, 0);
    ASSERT_EQ(played, *game.history);
}
