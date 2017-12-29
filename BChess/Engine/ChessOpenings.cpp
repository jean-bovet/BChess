//
//  ChessOpenings.cpp
//  BChess
//
//  Created by Jean Bovet on 12/29/17.
//  Copyright © 2017 Jean Bovet. All rights reserved.
//

#include "ChessOpenings.hpp"

ChessOpenings::ChessOpenings() {
    root.push({ e4 }, [](auto node) {
        node.score = 55;
    });

    root.push({ e4, c5 }, [](auto node) {
        node.score = 54;
        node.name = "Sicilian defense";
        node.site = "B20";
    });
    
    root.push({ e4, e5 }, [](auto & node) {
        node.score = 56;
        node.name = "King's pawn game";
        node.site = "C20";
    });

    root.push({ d4 }, [](auto node) {
        node.score = 56;
    });
    
}

OpeningTreeNode * ChessOpenings::lookup(ChessMoveList moves) {
    return root.lookup(moves);
}

OpeningTreeNode * ChessOpenings::best(ChessMoveList moves) {
    auto node = lookup(moves);
    if (node == nullptr) {
        return nullptr;
    }
    
    // Check if the opening book has some more moves for that particular node
    if (node->children.empty()) {
        return nullptr;
    }
    
    // Pick the first child which is the best one (sorted by score)
}
