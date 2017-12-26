//
//  ChessSearch.hpp
//  BChess
//
//  Created by Jean Bovet on 12/21/17.
//  Copyright © 2017 Jean Bovet. All rights reserved.
//

#pragma once

#include "FMoveList.hpp"

struct ChessEvaluation {
    MoveList line;
    
    int value = 0;
    
    int quiescenceDepth = 0;
    int depth = 0;
    
    // TODO: have a separate structure for the main line only
    int time = 0;
    int nodes = 0;
    int movesPerSecond = 0;
    
    bool cancelled = false;

    Color engineColor;
    
    void clear() {
        line.count = 0;
    }
    
};