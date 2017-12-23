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
    int quiescenceDepth = 0;
    int depth = 0;
    int time = 0;

    int nodes = 0;
    int movesPerSecond = 0;
    
    bool cancelled = false;

    Color engineColor;
    
    void addMove(Move move) {
        line.addMove(move);
    }
    
    void insertMove(int index, Move move) {
        line.insertMove(index, move);
    }
    
    Move bestMove() {
        return line._moves[0];
    }
};

typedef MinMaxSearch<Board, ChessMoveGenerator, ChessEvaluate, ChessEvaluation> ChessMinMaxSearch;
