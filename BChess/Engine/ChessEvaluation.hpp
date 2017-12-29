//
//  ChessSearch.hpp
//  BChess
//
//  Created by Jean Bovet on 12/21/17.
//  Copyright © 2017 Jean Bovet. All rights reserved.
//

#pragma once

#include "ChessMoveList.hpp"

struct ChessEvaluation {
    ChessMoveList line;
    
    int value = 0;
    
    int quiescenceDepth = 0;
    int depth = 0;
    
    int time = 0;
    int nodes = 0;
    int movesPerSecond = 0;
    
    Color engineColor = WHITE;
    
    void clear() {
        line.count = 0;
    }
    
};
