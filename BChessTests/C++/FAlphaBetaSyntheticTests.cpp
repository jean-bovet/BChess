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

class TestNode {
public:
    typedef std::function<void(TestNode &node)> TestNodeSetupCallback;
    
    void setValue(std::vector<int> indexes, int newValue) {
        push({ }, indexes, [&](TestNode &node) { node.value = newValue; });
    }

    void setQuiet(std::vector<int> indexes, bool quiet) {
        push({ }, indexes, [&](TestNode &node) { node.quiet = quiet; });
    }

    void setOrdering(std::vector<int> indexes, int ordering) {
        push({ }, indexes, [&](TestNode &node) { node.ordering = ordering; });
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
                _children.push_back(TestNode());
            }
            indexes.erase(indexes.begin());
            
            auto & child = _children[childIndex-1];
            child.parentIndexes = parentIndexes;
            child.index = childIndex;
            
            auto newParentIndexes = parentIndexes;
            newParentIndexes.push_back(childIndex);
            child.push(newParentIndexes, indexes, callback);
        }
    }
    
    std::vector<TestNode> children() {
        return _children;
    }
    
    bool isQuiet() {
        return quiet;
    }
    
    std::string description() {
        std::string text;
        for (auto pi : parentIndexes) {
            text += std::to_string(pi);
            text += ".";
        }
        text += std::to_string(index);
        text += "[";
        text += std::to_string(value);
        text += "]";
        return text;
    }
    
    std::vector<int> parentIndexes = { };
    int index = 0;
    int value = 0;
    int ordering = 0;
    bool quiet = true;
    std::vector<TestNode> _children = { };
};

bool operator<(const TestNode &lhs, const TestNode &rhs) {
    return lhs.ordering < rhs.ordering;
}

class TestEvaluater {
public:
    TestNode evaluate(TestNode node) {
        return node;
    }
};

template<class Node, class Evaluater>
static void assertAlphaBeta(AlphaBeta<Node, Evaluater, TestNode> alphaBeta, Node rootNode, int expectedVisitedNodes, int expectedValue) {
    alphaBeta.reset();
    
    alphaBeta.config.maxDepth = 4;
    
    auto eval = alphaBeta.alphabeta(rootNode, 0, INT_MIN, INT_MAX, true);
    std::cout << alphaBeta.visitedNodes << " => " << eval.value << std::endl;
    ASSERT_EQ(alphaBeta.visitedNodes, expectedVisitedNodes);
    ASSERT_EQ(eval.value, expectedValue);
}

static void configureTree(TestNode &rootNode) {
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

#pragma mark -

TEST(Synthetic, AlphaBetaCutoff) {
    TestEvaluater evaluater;
    AlphaBeta<TestNode, TestEvaluater, TestNode> alphaBeta(evaluater);
    
    TestNode rootNode;
    
    configureTree(rootNode);
    
    // Test with alpha-beta enabled (some nodes are skipped)
    assertAlphaBeta(alphaBeta, rootNode, 25, 6);
    
    // Test with alpha-beta disabled (all the nodes are analyzed)
    alphaBeta.config.alphaBetaPrunning = false;
    assertAlphaBeta(alphaBeta, rootNode, 33, 6);
}

TEST(Synthetic, SortedNodes) {
    TestEvaluater evaluater;
    AlphaBeta<TestNode, TestEvaluater, TestNode> alphaBeta(evaluater);
    
    TestNode rootNode;
    
    // The nodes are now sorted by best node first
    // which should lead to less nodes being analyzed by
    // the alpha-beta prunning algorithm.
    configureTree(rootNode);
    
    rootNode.setOrdering({ 2 }, 1);
    rootNode.setOrdering({ 1 }, 2);
    rootNode.setOrdering({ 3 }, 3);

    alphaBeta.config.maxDepth = 4;

    assertAlphaBeta(alphaBeta, rootNode, 21, 6);
}

TEST(Synthetic, QuiescenceSearch) {
    TestEvaluater evaluater;
    AlphaBeta<TestNode, TestEvaluater, TestNode> alphaBeta(evaluater);
    
    TestNode rootNode;
    
    configureTree(rootNode);

    // Let's add two nodes after the best ones (6) that are not good
    // to see if the quiescence search is able to detect those and avoid those.
    rootNode.setQuiet({ 2, 1, 1, 1 }, false); // change this node to a non-quiet node
    rootNode.setQuiet({ 2, 1, 2, 1 }, false); // change this node to a non-quiet node
    
    rootNode.setValue({ 2, 1, 1, 1, 1 }, 2);
    rootNode.setQuiet({ 2, 1, 1, 1, 1 }, false); // non-quiet node (it has been reached by a non-quiet move)

    rootNode.setValue({ 2, 1, 2, 1, 1 }, 9);
    rootNode.setQuiet({ 2, 1, 2, 1, 1 }, false); // change this node to a non-quiet node so the algorithm will continue it's quiescence search for the two following nodes

    rootNode.setValue({ 2, 1, 2, 1, 1, 1 }, 3);
    rootNode.setQuiet({ 2, 1, 2, 1, 1, 1 }, false); // non-quiet node (it has been reached by a non-quiet move)

    rootNode.setValue({ 2, 1, 2, 1, 1, 2 }, 4);
    rootNode.setQuiet({ 2, 1, 2, 1, 1, 2 }, false); // non-quiet node (it has been reached by a non-quiet move)

    // The best value is now 5 instead of 6
    assertAlphaBeta(alphaBeta, rootNode, 29, 5);
}

