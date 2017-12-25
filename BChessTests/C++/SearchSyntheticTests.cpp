//
//  FAlphaBetaTests.h
//  BChess
//
//  Created by Jean Bovet on 12/18/17.
//  Copyright © 2017 Jean Bovet. All rights reserved.
//

#include <gtest/gtest.h>

#include "ChessEngine.hpp"

#include <vector>
#include <map>

struct TestTreeNode {
    typedef std::function<void(TestTreeNode &node)> TestNodeSetupCallback;
    
    std::vector<TestTreeNode> _children = { };
    
    std::vector<int> indexes = { };

    int value = 0;
    int ordering = 0;
    bool quiet = true;

    void setValue(std::vector<int> indexes, int newValue) {
        push({ }, indexes, [&](TestTreeNode &node) { node.value = newValue; });
    }
    
    void setQuiet(std::vector<int> indexes, bool quiet) {
        push({ }, indexes, [&](TestTreeNode &node) { node.quiet = quiet; });
    }
    
    void setOrdering(std::vector<int> indexes, int ordering) {
        push({ }, indexes, [&](TestTreeNode &node) { node.ordering = ordering; });
    }
    
    void push(std::vector<int> indexes, TestNodeSetupCallback callback) {
        push({ }, indexes, callback);
    }
    
    void push(std::vector<int> parentIndexes, std::vector<int> indexes, TestNodeSetupCallback callback) {
        if (indexes.empty()) {
            callback(*this);
        } else {
            int childIndex = indexes.front();
            while (_children.size() < childIndex) {
                _children.push_back(TestTreeNode());
            }
            indexes.erase(indexes.begin());
            
            auto & child = _children[childIndex-1];
            
            auto newParentIndexes = parentIndexes;
            newParentIndexes.push_back(childIndex);
            
            child.indexes = newParentIndexes;
            
            child.push(newParentIndexes, indexes, callback);
        }
    }
    
};

struct TestMove {
    int index = 0;
    int ordering = 0;
    bool quiet = false;
};

struct TestMoveList {
    TestMove moves[256];
    int count = 0;
    
    void add(TestMove move) {
        moves[count] = move;
        count++;
    }
    
    void insertMove(int index, TestMove move) {
        moves[index] = move;
        count = index + 1;
    }
};

struct TestBoard {
    TestTreeNode *node = nullptr;
    
    void move(TestMove move) {
        node = &node->_children[move.index - 1];
    }
    
    std::string description() {
        std::string text;
        for (auto pi : node->indexes) {
            if (!text.empty()) {
                text += ".";
            }
            text += std::to_string(pi);
        }
        text += "[";
        text += std::to_string(node->value);
        text += "]";
        return text;
    }
    
};

struct TestEvaluater {
    static int evaluate(TestBoard board) {
        return board.node->value;
    }

    static int evaluate(TestBoard board, TestMoveList moves) {
        return evaluate(board);
    }

    static bool isQuiet(TestMove move) {
        return move.quiet;
    }
    
};

struct TestEvaluation {
    TestMoveList line;
    int value = 0;
    int depth = 0;
    int quiescenceDepth = 0;
    int nodes = 0;
    bool mat = false;
    bool cancelled = false;
    
    void add(int depth, TestMove move) {
        line.insertMove(depth, move);
    }
};

bool testMoveComparison(TestMove i, TestMove j) {
    return i.ordering < j.ordering;
}

struct TestMoveGenerator {
    
    static void sortMoves(TestMoveList & moveList) {
        std::sort(std::begin(moveList.moves), std::begin(moveList.moves)+moveList.count, testMoveComparison);
    }
    
    static TestMoveList generateMoves(TestBoard board) {
        TestMoveList moveList;
        for (int index=0; index<board.node->_children.size(); index++) {
            TestTreeNode child = board.node->_children[index];
            
            TestMove move;
            move.index = index+1;
            move.quiet = child.quiet;
            move.ordering = child.ordering;
            moveList.add(move);
        }
        return moveList;
    }
};

static void assertAlphaBeta(MinMaxSearch<TestBoard, TestMoveGenerator, TestMove, TestEvaluater, TestEvaluation> alphaBeta, TestTreeNode rootNode, int expectedVisitedNodes, int expectedValue, std::vector<int> expectedPV) {
    alphaBeta.reset();
        
    TestBoard board;
    board.node = &rootNode;
    
    TestEvaluation pv;
    int eval = alphaBeta.alphabeta(board, 0, true, pv);
//    std::cout << alphaBeta.visitedNodes << " => " << eval << std::endl;
    ASSERT_EQ(expectedValue, eval);
    ASSERT_EQ(expectedVisitedNodes, alphaBeta.visitedNodes);
    ASSERT_EQ(expectedPV.size(), pv.line.count);
    for (int index=0; index<expectedPV.size(); index++) {
        ASSERT_EQ(expectedPV[index], pv.line.moves[index].index);
    }
}

static void configureTree(TestTreeNode &rootNode) {
    rootNode.setValue({ 1, 1, 1, 1 }, 5);
    rootNode.setValue({ 1, 1, 1, 2 }, 6);
    
    rootNode.setValue({ 1, 1, 2, 1 }, 7);
    rootNode.setValue({ 1, 1, 2, 2 }, 4);
    rootNode.setValue({ 1, 1, 2, 3 }, 5);
    
    rootNode.setValue({ 1, 2, 1, 1 }, 3);
    
    rootNode.setValue({ 2, 1, 1, 1 }, 6);
    
    rootNode.setValue({ 2, 1, 2, 1 }, 6);
    rootNode.setValue({ 2, 1, 2, 2 }, 9);
    
    rootNode.setValue({ 2, 2, 1, 1 }, 7);
    
    rootNode.setValue({ 3, 1, 1, 1 }, 5);
    
    rootNode.setValue({ 3, 2, 1, 1 }, 9);
    rootNode.setValue({ 3, 2, 1, 2 }, 8);
    
    rootNode.setValue({ 3, 2, 2, 1 }, 6);
}

static MinMaxSearch<TestBoard, TestMoveGenerator, TestMove, TestEvaluater, TestEvaluation> defaultMinMaxSearch() {
    MinMaxSearch<TestBoard, TestMoveGenerator, TestMove, TestEvaluater, TestEvaluation> alphaBeta;
    alphaBeta.config.maxDepth = 4; // That's the height of the tree
    return alphaBeta;
}

#pragma mark -

TEST(Synthetic, AlphaBetaCutoff) {
    auto search = defaultMinMaxSearch();
    search.config.quiescenceSearch = false;
    
    TestTreeNode rootNode;

    configureTree(rootNode);
    
    // Test with alpha-beta enabled (some nodes are skipped)
    assertAlphaBeta(search, rootNode, 24, 6, { 2, 1, 1, 1 });
    
    // Test with alpha-beta disabled (all the nodes are analyzed)
    search.config.alphaBetaPrunning = false;
    assertAlphaBeta(search, rootNode, 32, 6, { 2, 1, 1, 1 });
}

TEST(Synthetic, SortedNodes) {
    auto search = defaultMinMaxSearch();
    
    TestTreeNode rootNode;

    // The nodes are now sorted by best node first
    // which should lead to less nodes being analyzed by
    // the alpha-beta prunning algorithm.
    configureTree(rootNode);
    
    rootNode.setOrdering({ 2 }, 1);
    rootNode.setOrdering({ 1 }, 2);
    rootNode.setOrdering({ 3 }, 3);

    assertAlphaBeta(search, rootNode, 20, 6, { 2, 1, 1, 1 });
}

TEST(Synthetic, QuiescenceSearch) {
    auto search = defaultMinMaxSearch();

    TestTreeNode rootNode;

    configureTree(rootNode);

    // Let's add two nodes after the best ones (6) that are not good
    // to see if the quiescence search is able to detect those and avoid those.
    rootNode.setQuiet({ 2, 1, 1, 1 }, false); // change this node to a non-quiet node
    rootNode.setQuiet({ 2, 1, 2, 1 }, false); // change this node to a non-quiet node
    
    rootNode.setValue({ 2, 1, 1, 1, 1 }, 12); // must be better than 6
    rootNode.setQuiet({ 2, 1, 1, 1, 1 }, false); // non-quiet node (it has been reached by a non-quiet move)

    rootNode.setValue({ 2, 1, 2, 1, 1 }, 8); // must be better than 6
    rootNode.setQuiet({ 2, 1, 2, 1, 1 }, false); // change this node to a non-quiet node so the algorithm will continue it's quiescence search for the two following nodes

    rootNode.setValue({ 2, 1, 2, 1, 1, 1 }, 3); // must be lower than 7
    rootNode.setQuiet({ 2, 1, 2, 1, 1, 1 }, false); // non-quiet node (it has been reached by a non-quiet move)

    rootNode.setValue({ 2, 1, 2, 1, 1, 2 }, 4); // must be lower than 7
    rootNode.setQuiet({ 2, 1, 2, 1, 1, 2 }, false); // non-quiet node (it has been reached by a non-quiet move)

    // The best value is now 7 instead of 6
    assertAlphaBeta(search, rootNode, 26, 7, { 2, 2, 1, 1 });
}

