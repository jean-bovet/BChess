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

class FFEN {
public:
    static std::string getFEN(ChessBoard board);
    static bool setFEN(std::string fen, ChessBoard &board);
};

