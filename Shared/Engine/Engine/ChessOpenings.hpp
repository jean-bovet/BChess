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

#include "ChessGame.hpp"

class ChessOpenings {
private:
    std::vector<ChessGame> games;

public:

    ChessOpenings();
    
    bool load(std::string pgn);
    
    // Structure containing the information about a specific move in an opening
    struct OpeningMove {
        // The move itself
        Move move;
        // The name of the opening containing this move
        std::string name;
        // The score of the opening containing this move
        int score;
        // The array of moves after this one as defined by the opening.
        // The first element in the array is always the main line.
        std::vector<Move> nextMoves;        
    };
    
    typedef std::function<void(OpeningMove move)> OpeningCallback;
    typedef std::function<void(std::vector<OpeningMove> moves)> OpeningsCallback;

    // This function looks up the best opening corresponding to
    // the specified list of moves (which can be empty).
    // Returns false if no opening is found
    bool lookup(std::vector<Move> moves, OpeningCallback callback);

    // This function looks up all the openins corresponding to
    // the specified list of moves (which can be empty).
    // Returns false if no opening is found
    bool lookupAll(std::vector<Move> moves, OpeningsCallback callback);

    // This function looks up the best next move given by the opening
    // that matches the list of moves (which can be empty).
    // Returns false if no opening is found
    bool best(std::vector<Move> moves, OpeningCallback callback);
    
};
