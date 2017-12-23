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
    static bool isQuiet(Move move);
    
    static int evaluate(Board board, MoveList moves);

    static int evaluate(Board board);

    static int getBonus(Piece piece, Color color, Square square);
};
