//
//  FTests.hpp
//  BChess
//
//  Created by Jean Bovet on 12/2/17.
//  Copyright © 2017 Jean Bovet. All rights reserved.
//

#include <gtest/gtest.h>

#include <iostream>
#include <sstream>
#include <fstream>

#include "UnitTestHelper.hpp"
#include "ChessOpenings.hpp"
#include "ChessEngine.hpp"
#include "ChessGame.hpp"
#include "FPGN.hpp"

class OpeningsTests: public ::testing::Test {
public:
    
    ChessOpenings openings;
    
    void SetUp() {
        ChessEngine::initialize();
    }

    bool lookupOpeningNode(ChessOpenings &openings, std::string pgn, OpeningTreeNode &outNode) {
        ChessGame temp;
        if (!FPGN::setGame(pgn, temp)) {
            return false;
        }
        
        OpeningTreeNode node;
        bool result = openings.lookup(temp.moves, [&](auto & node) {
            outNode = node;
        });
        
        return result;
    }
    
    std::string readFromFile(std::string file) {
        std::ifstream input(file);
        std::stringstream sstr;
        
        while(input >> sstr.rdbuf());
        
        return sstr.str();
    }

};

TEST_F(OpeningsTests, Loading) {
    auto path = UnitTestHelper::pathToResources;
    auto pathToFile = path + "/Openings.pgn";
    
    ChessOpenings openings;
    auto pgn = readFromFile(pathToFile);
    ASSERT_FALSE(pgn.empty());
    ASSERT_TRUE(openings.load(pgn));
    
    OpeningTreeNode node;
    ASSERT_TRUE(lookupOpeningNode(openings, "1. e4 c5", node));
    
    ASSERT_EQ(54, node.score);
    ASSERT_EQ("Sicilian defense", node.name);
    ASSERT_EQ("B20", node.eco);
}

TEST_F(OpeningsTests, KingsPawnOpening) {
    Move m;
    MoveList moves;
    moves.push(m = createMove(e2, e4, WHITE, PAWN));
    
    bool result = openings.lookup(moves, [&](auto & node) {
        ASSERT_EQ(m, node.move);
    });
    ASSERT_TRUE(result);
    
    moves.push(m = createMove(e7, e5, BLACK, PAWN));
    result = openings.lookup(moves, [&](auto & node) {
        ASSERT_EQ(m, node.move);
        ASSERT_EQ("King's pawn game", node.name);
    });
    ASSERT_TRUE(result);

    moves.push(createMove(e2, e4, WHITE, PAWN));
    result = openings.lookup(moves, [&](auto & node) {
        FAIL();
    });
    ASSERT_FALSE(result);
}

TEST_F(OpeningsTests, BestMove) {
    MoveList moves;
    
    bool result = openings.best(moves, [&](auto & node) {
        ASSERT_EQ(createMove(d2, d4, WHITE, PAWN), node.move);
    });
    ASSERT_TRUE(result);
    
    moves.push(createMove(e2, e4, WHITE, PAWN));
    
    result = openings.best(moves, [&](auto & node) {
        ASSERT_EQ(createMove(e7, e5, BLACK, PAWN), node.move);
    });
    ASSERT_TRUE(result);
}
