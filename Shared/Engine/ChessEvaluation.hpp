//
//  ChessSearch.hpp
//  BChess
//
//  Created by Jean Bovet on 12/21/17.
//  Copyright © 2017 Jean Bovet. All rights reserved.
//

#pragma once

#include <cstdint>

#include "MoveList.hpp"

struct ChessEvaluation {
    MoveList line;
        
    int value = 0;
    
    int quiescenceDepth = 0;
    int depth = 0;
    // The deepest ply visited in the depth that produced this evaluation
    int selDepth = 0;
    
    // Totals since the search started: milliseconds, and nodes
    int64_t time = 0;
    int64_t nodes = 0;
    int64_t movesPerSecond = 0;
    
    Color engineColor = WHITE;
    
    void clear() {
        line.count = 0;
    }
    
};
