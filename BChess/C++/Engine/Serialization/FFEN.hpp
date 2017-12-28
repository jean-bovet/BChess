//
//  FFEN.hpp
//  BChess
//
//  Created by Jean Bovet on 11/30/17.
//  Copyright © 2017 Jean Bovet. All rights reserved.
//

#pragma once

#include <stdio.h>
#include "ChessBoard.hpp"

static const char * StartFEN = "rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1";

class FFEN {
public:
    static std::string getFEN(ChessBoard board);
    static bool setFEN(std::string fen, ChessBoard &board);
};

