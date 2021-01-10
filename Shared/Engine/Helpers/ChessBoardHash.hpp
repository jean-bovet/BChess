//
//  ChessBoardHash.hpp
//  BChess
//
//  Created by Jean Bovet on 1/6/18.
//  Copyright © 2018 Jean Bovet. All rights reserved.
//

#pragma once

#include "ChessBoard.hpp"
#include "Types.hpp"

class ChessBoardHash {    
public:
    static void initialize();
    
    static BoardHash hash(ChessBoard board);
    
    static uint64_t getPseudoNumber(Square square, Color color, Piece piece);
    
    static uint64_t getWhiteTurn();
};
