//
//  ChessEngine.h
//  BChess
//
//  Created by Jean Bovet on 12/23/17.
//  Copyright © 2017 Jean Bovet. All rights reserved.
//

#pragma once

#include "Types.hpp"
#include "MinMaxSearch.hpp"
#include "ChessBoard.hpp"
#include "ChessBoardHash.hpp"
#include "ChessMoveGenerator.hpp"
#include "ChessEvaluater.hpp"
#include "ChessEvaluation.hpp"

typedef MinMaxSearch ChessMinMaxSearch;

class ChessEngine {
public:
    static void initialize() {
        ChessMoveGenerator::initialize();
        ChessBoardHash::initialize();
    }
};
