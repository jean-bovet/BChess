//
//  FPerformance.hpp
//  BChess
//
//  Created by Jean Bovet on 11/30/17.
//  Copyright © 2017 Jean Bovet. All rights reserved.
//

#ifndef FPerformance_hpp
#define FPerformance_hpp

#include "FBoard.hpp"
#include <stdio.h>

class FPerformance {
    FastMoveGenerator generator;
    
public:
    int moveCount = 0;

    void generateMoves(Board board, Color color, int depth);
};

#endif /* FPerformance_hpp */
