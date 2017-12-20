//
//  FAlphaBetaTests.h
//  BChess
//
//  Created by Jean Bovet on 12/18/17.
//  Copyright © 2017 Jean Bovet. All rights reserved.
//

#include <gtest/gtest.h>

#include "FAlphaBeta.hpp"
#include "FEvaluate.hpp"
#include "FMoveGenerator.hpp"

#include <vector>
#include <map>

class ChessNode {
public:
    Board board;
    
    ChessNode(Board board) : board(board) { }
    
    std::vector<ChessNode> children() {
        std::vector<ChessNode> nodes;
        MoveGenerator generator;
        auto moveList = generator.generateMoves(board);
        for (auto move : moveList.moves) {
            auto newBoard = board;
            newBoard.move(move);
            nodes.push_back(ChessNode(newBoard));
        }
        return nodes;
    }
    
    bool isQuiet() {
        return true;
    }
    
    std::string description() {
        return "";
    }
};

class ChessEvaluater {
public:
    int evaluate(ChessNode node) {
        return Evaluate::evaluate(node.board);
    }
};

static void assertChessSearch(int expectedVisitedNodes, int expectedValue, bool alphaBetaCutoff = true) {
    ChessEvaluater evaluater;
    AlphaBeta<ChessNode, ChessEvaluater> alphaBeta(evaluater, 4);
    
    Board rootBoard;
    rootBoard.print();
    ChessNode rootNode(rootBoard);
    alphaBeta.alphaBetaCutoff = alphaBetaCutoff;
    int value = alphaBeta.alphabeta(rootNode, 0, INT_MIN, INT_MAX, true);
    std::cout << alphaBeta.visitedNodes << " => " << value << std::endl;
    ASSERT_EQ(alphaBeta.visitedNodes, expectedVisitedNodes); // n initial moves + 1 for the root node
    ASSERT_EQ(value, expectedValue);
}

TEST(Chess, ChessTree) {
    assertChessSearch(25890, 0, true); // with alpha-beta prunning
    assertChessSearch(206604, 0, false); // without alpha-beta
}

