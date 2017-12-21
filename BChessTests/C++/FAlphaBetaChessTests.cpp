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
#include "FFEN.hpp"
#include "FPGN.hpp"

#include <vector>
#include <map>

class ChessNode {
public:
    Board board;
    MoveList moves; // moves that lead to that board
    
    bool generatedChildren = false;
    bool quiet = true;
    std::vector<ChessNode> _children;
    
    ChessNode(Board board) : board(board) { }
    
    std::vector<ChessNode> children(bool activeChildrenOnly) {
        if (!generatedChildren) {
            generatedChildren = true;
            
            MoveGenerator generator;
            auto moveList = generator.generateMoves(board);
            for (auto move : moveList.moves) {
                if (activeChildrenOnly && !MOVE_IS_CAPTURE(move)) {
                    continue;
                }
                
                auto newBoard = board;
                newBoard.move(move);
                
                auto child = ChessNode(newBoard);
                child.moves.addMoves(moves);
                child.moves.addMove(move);
                
                if (MOVE_IS_CAPTURE(move)) {
                    quiet = false;
                }
                
                _children.push_back(child);
            }
        }
        return _children;
    }
    
    bool isQuiet() {
        return quiet;
    }
    
    std::string description() {
        std::string text = moves.description();
        text += " ";
        text += std::to_string(value);
        return text;
    }
    
    int value = 0;
};

bool operator<(const ChessNode &lhs, const ChessNode &rhs) {
    return lhs.value < lhs.value;
}

struct ChessEvaluation {
    MoveList line;
    int value = 0;
};

class ChessEvaluater {
public:
    ChessEvaluation evaluate(ChessNode & node) {
        ChessEvaluation evaluation;
        evaluation.value = Evaluate::evaluate(node.board);
        evaluation.line = node.moves;
        node.value = evaluation.value;
        return evaluation;
    }
};

static void assertChessSearch(int expectedVisitedNodes, int expectedValue, Configuration config) {
    config.maxDepth = 4;
    
    ChessEvaluater evaluater;
    AlphaBeta<ChessNode, ChessEvaluater, ChessEvaluation> alphaBeta(evaluater, config);
    
    Board rootBoard;
    ChessNode rootNode(rootBoard);

    auto eval = alphaBeta.alphabeta(rootNode, 0, INT_MIN, INT_MAX, true, false);
    std::cout << alphaBeta.visitedNodes << " => " << eval.value << std::endl;
    ASSERT_EQ(alphaBeta.visitedNodes, expectedVisitedNodes); // n initial moves + 1 for the root node
    ASSERT_EQ(eval.value, expectedValue);
}

TEST(Chess, ChessTree) {
    Configuration config;
    config.quiescenceSearch = false;

    config.alphaBetaPrunning = true;
    assertChessSearch(25890, 0, config); // with alpha-beta prunning
    
    config.alphaBetaPrunning = false;
    assertChessSearch(206604, 0, config); // without alpha-beta
}

TEST(Chess, OrderedMove) {
    auto fen = "r1bqkbnr/pppp1ppp/2n5/3P4/8/8/PPP2PPP/RNBQKBNR b KQkq - 0 5";
    Board board;
    ASSERT_TRUE(FFEN::setFEN(fen, board));
        
    Configuration config;
    config.maxDepth = 4;
    config.debugLog = false;
    ChessEvaluater evaluater;
    AlphaBeta<ChessNode, ChessEvaluater, ChessEvaluation> alphaBeta(evaluater, config);
    ChessNode rootNode(board);

    auto eval = alphaBeta.alphabeta(rootNode, 0, INT_MIN, INT_MAX, board.color == WHITE, false);
    std::cout << alphaBeta.visitedNodes << " => " << eval.value << " for " << eval.line.description() << std::endl;
}
