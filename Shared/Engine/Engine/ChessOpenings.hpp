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

#include "MoveList.hpp"

struct OpeningTreeNode {
    Move move;
    int score = 0;
    std::string name;
    std::string eco;
        
    std::map<Move, OpeningTreeNode> children;
    
    typedef std::function<void(OpeningTreeNode &node)> NodeCallback;

    void clear() {
        children.clear();
    }

    void push(std::vector<Move> moves, NodeCallback callback) {
        MoveList moveList;
        for (auto move : moves) {
            moveList.push(move);
        }
        push(moveList, 0, callback);
    }
    
    void push(MoveList moves, int moveIndex, NodeCallback callback) {
        callback(*this);
        if (moveIndex < moves.count) {
            auto key = moves[moveIndex];
            auto & child = children[key];
            child.move = key;
            child.push(moves, moveIndex+1, callback);
        }
    }

    bool lookup(std::vector<Move> moves, NodeCallback callback) {
        MoveList moveList;
        for (auto move : moves) {
            moveList.push(move);
        }
        return lookup(moveList, 0, callback);
    }
    
    bool lookup(MoveList moves, int moveIndex, NodeCallback callback) {
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
public:
    OpeningTreeNode root;

    ChessOpenings();
    
    bool load(std::string pgn);
    
    bool lookup(std::vector<Move> moves, OpeningTreeNode::NodeCallback callback);

    bool best(std::vector<Move> moves, OpeningTreeNode::NodeCallback callback);
    
};
