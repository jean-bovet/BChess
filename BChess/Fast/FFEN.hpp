//
//  FFEN.hpp
//  BChess
//
//  Created by Jean Bovet on 11/30/17.
//  Copyright © 2017 Jean Bovet. All rights reserved.
//

#pragma once

#include <stdio.h>
#include "FBoard.hpp"

class FFEN {
public:
    static Board createBoard(std::string fen);
};

