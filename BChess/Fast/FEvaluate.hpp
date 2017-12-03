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

class Evaluate {
public:
    static int evaluate(Board board);
    static int evaluate(Board board, MoveList moves);
};
