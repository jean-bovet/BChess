//
//  FMove.hpp
//  BChess
//
//  Created by Jean Bovet on 12/3/17.
//  Copyright © 2017 Jean Bovet. All rights reserved.
//

#pragma once

#include "FColor.hpp"
#include "FPiece.hpp"

struct Move {
    int from;
    int to;
    Color color;
    Piece piece;
};


