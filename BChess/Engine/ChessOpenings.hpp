//
//  ChessOpenings.hpp
//  BChess
//
//  Created by Jean Bovet on 12/29/17.
//  Copyright © 2017 Jean Bovet. All rights reserved.
//

#pragma once

#include <string>
#include <map>
#include <vector>

#include "ChessMoveList.hpp"

struct OpeningTreeNode {
    Move move;
    int score = 0;
    std::string name;
    std::string site;
        
    std::map<Move, OpeningTreeNode> children;
    
    typedef std::function<void(OpeningTreeNode &node)> NodeCallback;

    void push(std::vector<Move> line, NodeCallback callback) {
        if (line.empty()) {
            callback(*this);
        } else {
            auto key = line.front();
            auto & child = children[key];
            line.erase(line.begin());
            child.move = key;
            child.push(line, callback);
        }
    }
    
    bool lookup(ChessMoveList moves, int moveIndex, NodeCallback callback) {
        if (moveIndex < moves.count) {
            Move move = moves[moveIndex];
            if (children.count(move) == 0) {
                return false;
            } else {
                auto & child = children[move];
                return child.lookup(moves, moveIndex+1, callback);
            }
        } else {
            callback(*this);
            return true;
        }
    }
    
};

class ChessOpenings {
    OpeningTreeNode root;
    
public:
    ChessOpenings();
    
    bool lookup(ChessMoveList moves, OpeningTreeNode::NodeCallback callback);

    bool best(ChessMoveList moves, OpeningTreeNode::NodeCallback callback);
    
};
