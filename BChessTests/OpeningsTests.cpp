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

    bool lookupOpeningNode(ChessOpenings &openings, std::string pgn, ChessOpenings::OpeningMove &outNode) {
        ChessGame temp;
        if (!FPGN::setGame(pgn, temp)) {
            return false;
        }

        ChessGame::MoveNode node;
        bool result = openings.lookup(temp.allMoves(), [&](auto node) {
            outNode = node;
        });

        return result;
    }
    
    void initializeDefaultOpenings() {
        loadOpenings("Openings.pgn");
    }
    
    void loadOpenings(std::string name) {
        auto path = UnitTestHelper::pathToResources;
        auto pathToFile = path + "/" + name;
        
        auto pgn = readFromFile(pathToFile);
        ASSERT_FALSE(pgn.empty());
        ASSERT_TRUE(openings.load(pgn));
    }
    
    std::string readFromFile(std::string file) {
        std::ifstream input(file);
        std::stringstream sstr;
        
        while(input >> sstr.rdbuf());
        
        return sstr.str();
    }

};

TEST_F(OpeningsTests, Loading) {
    initializeDefaultOpenings();

    ChessOpenings::OpeningMove node;
    
    // Play openings that exist in the book
    ASSERT_TRUE(lookupOpeningNode(openings, "1. e4 c5", node));
    ASSERT_EQ(54, node.score);
    ASSERT_EQ("Sicilian defense", node.name);

    ASSERT_TRUE(lookupOpeningNode(openings, "1. e4 e5", node));
    ASSERT_EQ(58, node.score);
    ASSERT_EQ("Ruy López Opening: Morphy Defense, Columbus Variation, 4...Nf6", node.name);

    // Play an opening that does not exist
    ASSERT_FALSE(lookupOpeningNode(openings, "1. e4 e6", node));
}

TEST_F(OpeningsTests, OpeningWithVariation) {
    ChessOpenings::OpeningMove node;

    ASSERT_TRUE(openings.load("1. e4 e5"));

    ASSERT_TRUE(lookupOpeningNode(openings, "1. e4 e5", node));
    ASSERT_FALSE(lookupOpeningNode(openings, "1. e4 c5", node));

    ASSERT_TRUE(openings.load("1. e4 e5 (1... c5)"));

    ASSERT_TRUE(lookupOpeningNode(openings, "1. e4 e5", node));
    ASSERT_TRUE(lookupOpeningNode(openings, "1. e4 c5", node));
}

TEST_F(OpeningsTests, KingsPawnOpening) {
    initializeDefaultOpenings();

    Move m;
    std::vector<Move> moves;
    moves.push_back(m = createMove(e2, e4, WHITE, PAWN));
    
    bool result = openings.lookup(moves, [&](auto node) {
        ASSERT_EQ(m, node.move);
    });
    ASSERT_TRUE(result);
    
    moves.push_back(m = createMove(e7, e5, BLACK, PAWN));
    result = openings.lookup(moves, [&](auto node) {
        ASSERT_EQ(m, node.move);
        ASSERT_EQ("Ruy López Opening: Morphy Defense, Columbus Variation, 4...Nf6", node.name);
    });
    ASSERT_TRUE(result);

    moves.push_back(createMove(e2, e4, WHITE, PAWN));
    result = openings.lookup(moves, [&](auto node) {
        FAIL();
    });
    ASSERT_FALSE(result);
}

TEST_F(OpeningsTests, BestMove) {
    initializeDefaultOpenings();

    std::vector<Move> moves;

    bool result = openings.best(moves, [&](auto node) {
        ASSERT_EQ(createMove(e2, e4, WHITE, PAWN), node.move);
    });
    ASSERT_TRUE(result);
    
    moves.push_back(createMove(e2, e4, WHITE, PAWN));
    
    result = openings.best(moves, [&](auto node) {
        ASSERT_EQ(createMove(e7, e5, BLACK, PAWN), node.move);
    });
    ASSERT_TRUE(result);
}

TEST_F(OpeningsTests, MultipleWhiteVariations) {
    ASSERT_TRUE(openings.load("1.e4 e5 2.Nf3 ( 2.Nc3 ) ( 2.d4 ) *"));
}

TEST_F(OpeningsTests, MultipleBlackVariations) {
    ASSERT_TRUE(openings.load("1.e4 e5 ( 1...Nf6 ) ( 1...c6 ) *"));
}
