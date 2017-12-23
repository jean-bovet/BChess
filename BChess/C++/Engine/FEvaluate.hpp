//
//  FEvaluate.hpp
//  BChess
//
//  Created by Jean Bovet on 12/3/17.
//  Copyright © 2017 Jean Bovet. All rights reserved.
//

#pragma once

#include "FBoard.hpp"
#include "FMoveList.hpp"

class ChessEvaluate {
public:
    // Mat value which must be lower than INT_MIN or INT_MAX
    // otherwise it causes issue with the min-max algorithm
    // when rewinding (only the first move is registered, not
    // the line of moves to the mat).
    static const int MAT_VALUE = 100000;
    
    static bool isQuiet(Move move);
    
    static int evaluate(Board board, MoveList moves);

    static int evaluate(Board board);

    static int getBonus(Piece piece, Color color, Square square);
};
