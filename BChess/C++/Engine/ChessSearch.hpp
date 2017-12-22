//
//  ChessSearch.hpp
//  BChess
//
//  Created by Jean Bovet on 12/21/17.
//  Copyright © 2017 Jean Bovet. All rights reserved.
//

#pragma once

#include "MinMaxSearch.hpp"
#include "FBoard.hpp"
#include "FMoveList.hpp"
#include "FEvaluate.hpp"
#include "FMoveGenerator.hpp"

#include <vector>

struct ChessEvaluation {
    MoveList line;
    int value = 0;
    void addMove(Move move) {
        line.addMove(move);
    }
    void insertMove(int index, Move move) {
        line.insertMove(index, move);
    }
};
