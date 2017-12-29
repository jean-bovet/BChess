//
//  ChessOpenings.cpp
//  BChess
//
//  Created by Jean Bovet on 12/29/17.
//  Copyright © 2017 Jean Bovet. All rights reserved.
//

#include "ChessOpenings.hpp"
#include "FPGN.hpp"

ChessOpenings::ChessOpenings() {
    root.push({ createMove(e2, e4, WHITE, PAWN) }, [](auto & node) {
        node.score = 55;
    });

    root.push({ createMove(e2, e4, WHITE, PAWN), createMove(c7, c5, BLACK, PAWN) }, [](auto & node) {
        node.score = 54;
        node.name = "Sicilian defense";
        node.site = "B20";
    });
    
    root.push({ createMove(e2, e4, WHITE, PAWN), createMove(e7, e5, BLACK, PAWN) }, [](auto & node) {
        node.score = 56;
        node.name = "King's pawn game";
        node.site = "C20";
    });

    root.push({ createMove(d2, d4, WHITE, PAWN) }, [](auto & node) {
        node.score = 56;
    });
    
}

bool ChessOpenings::load(std::string pgn) {
    std::vector<ChessGame> games;
    if (FPGN::setGames(pgn, games)) {
        root.clear();
        for (auto game : games) {
            root.push(game.moves, 0, [&](auto & node) {
                auto score = game.tags["Score"];
                if (score.length() > 0) {
                    node.score = stoi(score);
                }
                node.name = game.tags["Name"];
            });
        }
        return true;
    } else {
        return false;
    }
}

bool ChessOpenings::lookup(ChessMoveList moves, OpeningTreeNode::NodeCallback callback) {
    return root.lookup(moves, 0, callback);
}

bool nodeComparison(OpeningTreeNode i, OpeningTreeNode j) {
    return i.score > j.score;
}

bool ChessOpenings::best(ChessMoveList moves, OpeningTreeNode::NodeCallback callback) {
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
