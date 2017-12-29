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
    Square move;
    int score = 0;
    std::string name;
    std::string site;
    std::map<Square, OpeningTreeNode> children;
    
    typedef std::function<void(OpeningTreeNode &node)> PushCallback;

    void push(std::vector<Square> line, PushCallback callback) {
        if (line.empty()) {
            callback(*this);
        } else {
            auto key = line.front();
            auto & child = children[key];
            line.erase(line.begin());
            child.push(line, callback);
        }
    }
    
    OpeningTreeNode * lookup(ChessMoveList moves, int moveIndex = 0) {
        if (moveIndex < moves.count) {
            Move move = moves[moveIndex];
            Square key = MOVE_TO(move);
            if (children.count(key) == 0) {
                return nullptr;
            } else {
                auto & child = children[key];
                return child.lookup(moves, moveIndex+1);
            }
        } else {
            return this;
        }
    }
    
};

class ChessOpenings {
    OpeningTreeNode root;
    
public:
    ChessOpenings();
    
    OpeningTreeNode* lookup(ChessMoveList moves);

    OpeningTreeNode* best(ChessMoveList moves);
    
};
