//
//  ChessOpenings.cpp
//  BChess
//
//  Created by Jean Bovet on 12/29/17.
//  Copyright © 2017 Jean Bovet. All rights reserved.
//

#include "ChessOpenings.hpp"
#include "FPGN.hpp"
#include "FUtility.hpp"

ChessOpenings::ChessOpenings() {
}

bool ChessOpenings::load(std::string pgn) {
    std::vector<ChessGame> games;
    if (FPGN::setGames(pgn, games)) {
        root.clear();
        
        for (auto game : games) {
            auto scoreString = game.tags["Score"];
            auto score = 0;
            if (scoreString.length() > 0) {
                score = integer(scoreString);
            }
            auto name = game.tags["Name"];
            auto eco = game.tags["ECO"];

            root.push(game.moves, 0, [&](auto & node) {
                // Make sure the node always contain
                // the best score so that branch is always
                // taken upon lookup.
                if (node.score < score) {
                    node.score = score;
                    node.name = name;
                    node.eco = eco;
                }
            });
        }
        return true;
    } else {
        return false;
    }
}

bool ChessOpenings::lookup(MoveList moves, OpeningTreeNode::NodeCallback callback) {
    return root.lookup(moves, 0, callback);
}

bool nodeComparison(OpeningTreeNode i, OpeningTreeNode j) {
    return i.score > j.score;
}

bool ChessOpenings::best(MoveList moves, OpeningTreeNode::NodeCallback callback) {
    bool bestFound = false;
    bool result = lookup(moves, [&](auto & node) {
        // Check if the opening book has some more moves for that particular node
        if (node.children.empty()) {
            bestFound = false;
        } else {
            // Pick the child with the best score
            std::vector<OpeningTreeNode> sortedChildren;
            for (auto entry : node.children) {
                sortedChildren.push_back(entry.second);
            }
            std::sort(sortedChildren.begin(), sortedChildren.end(), nodeComparison);
            auto & best = sortedChildren.front();
            callback(best);
            bestFound = true;
        }
    });
    
    return result && bestFound;
}
