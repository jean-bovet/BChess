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
    void push(std::vector<int> indexes, int newValue, bool quiet = true) {
        push({ }, indexes, newValue, quiet);
    }
    
    void push(std::vector<int> parentIndexes, std::vector<int> indexes, int newValue, bool quiet = true) {
        if (indexes.empty()) {
            TestNode::value = newValue;
            TestNode::quiet = quiet;
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
            child.push(newParentIndexes, indexes, newValue, quiet);
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
    bool quiet = true;
    std::vector<TestNode> _children = { };
};

class TestEvaluater {
public:
    int evaluate(TestNode node) {
        return node.value;
    }
};

template<class Node, class Evaluater>
static void assertAlphaBeta(AlphaBeta<Node, Evaluater> alphaBeta, Node rootNode, int expectedVisitedNodes, int expectedValue, bool alphaBetaCutoff = true) {
    alphaBeta.reset();
    alphaBeta.alphaBetaCutoff = alphaBetaCutoff;
    
    int value = alphaBeta.alphabeta(rootNode, 0, INT_MIN, INT_MAX, true);
    std::cout << alphaBeta.visitedNodes << " => " << value << std::endl;
    ASSERT_EQ(alphaBeta.visitedNodes, expectedVisitedNodes);
    ASSERT_EQ(value, expectedValue);
}

static void configureTree(TestNode &rootNode) {
    rootNode.push({ 1, 1, 1, 1 }, 5);
    rootNode.push({ 1, 1, 1, 2 }, 6);
    
    rootNode.push({ 1, 1, 2, 1 }, 7);
    rootNode.push({ 1, 1, 2, 2 }, 4);
    rootNode.push({ 1, 1, 2, 3 }, 5);
    
    rootNode.push({ 1, 2, 1, 1 }, 3);
    
    rootNode.push({ 2, 1, 1, 1 }, 6);
    
    rootNode.push({ 2, 1, 2, 1 }, 6);
    rootNode.push({ 2, 1, 2, 2 }, 9);
    
    rootNode.push({ 2, 2, 1, 1 }, 7);
    
    rootNode.push({ 3, 1, 1, 1 }, 5);
    
    rootNode.push({ 3, 2, 1, 1 }, 9);
    rootNode.push({ 3, 2, 1, 2 }, 8);
    
    rootNode.push({ 3, 2, 2, 1 }, 6);
}

static void configureTreeWithBestBranchFirst(TestNode &rootNode) {
    // 1st node
    rootNode.push({ 2, 1, 1, 1 }, 5);
    rootNode.push({ 2, 1, 1, 2 }, 6);
    
    rootNode.push({ 2, 1, 2, 1 }, 7);
    rootNode.push({ 2, 1, 2, 2 }, 4);
    rootNode.push({ 2, 1, 2, 3 }, 5);
    
    rootNode.push({ 2, 2, 1, 1 }, 3);
    
    // 2nd node
    rootNode.push({ 1, 1, 1, 1 }, 6);
    
    rootNode.push({ 1, 1, 2, 1 }, 6);
    rootNode.push({ 1, 1, 2, 2 }, 9);
    
    rootNode.push({ 1, 2, 1, 1 }, 7);
    
    // 3rd node
    rootNode.push({ 3, 1, 1, 1 }, 5);
    
    rootNode.push({ 3, 2, 1, 1 }, 9);
    rootNode.push({ 3, 2, 1, 2 }, 8);
    
    rootNode.push({ 3, 2, 2, 1 }, 6);
}

TEST(Synthetic, FakeTree) {
    TestEvaluater evaluater;
    AlphaBeta<TestNode, TestEvaluater> alphaBeta(evaluater, 4);
    
    TestNode rootNode;
    
    configureTree(rootNode);
    
    assertAlphaBeta(alphaBeta, rootNode, 25, 6);
    assertAlphaBeta(alphaBeta, rootNode, 33, 6, false);
    
    // Let's add two nodes after the best ones (6) that are not good
    // to see if the quiescence search is able to detect those and avoid those.
    rootNode.push({ 2, 1, 1, 1 }, 6, false); // change this node to a non-quiet node
    rootNode.push({ 2, 1, 2, 1 }, 6, false); // change this node to a non-quiet node
    
    rootNode.push({ 2, 1, 1, 1, 1 }, 2, false);
    rootNode.push({ 2, 1, 2, 1, 1 }, 2, false);
    
    assertAlphaBeta(alphaBeta, rootNode, 30, 5); // why 30 nodes visited? print out which ones were cut off
    
    rootNode.push({ 2, 1, 1, 1, 1 }, 2, true);
    rootNode.push({ 2, 1, 2, 1, 1 }, 2, true);
    
    assertAlphaBeta(alphaBeta, rootNode, 30, 5);
    
    // TODO: display the nodes visited and the one skipped?
    TestNode rootNode2;
    configureTreeWithBestBranchFirst(rootNode2);
    assertAlphaBeta(alphaBeta, rootNode2, 21, 6);
}

