//
//  ChessState.hpp
//  BChess
//
//  Created by Jean Bovet on 3/3/18.
//  Copyright © 2018 Jean Bovet. All rights reserved.
//

#pragma once

#include "ChessBoard.hpp"
#include <map>

class ChessState {
private:
    struct PieceInstance {
        char p;        
        int count;
        bool empty;
    };
    
    std::map<char, int> pieceCount;
    std::map<Square, PieceInstance> squareContent;

public:
    void set(ChessBoard board);
    void update(ChessBoard board);
    std::string getState();
};
