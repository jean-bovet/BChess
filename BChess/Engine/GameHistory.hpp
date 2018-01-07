//
//  GameHistory.hpp
//  BChess
//
//  Created by Jean Bovet on 1/6/18.
//  Copyright © 2018 Jean Bovet. All rights reserved.
//

#pragma once

#include "Types.hpp"

class ChessHistory {        
public:
    static bool isThreefoldRepetition(BoardHash hash, HistoryPtr history);
};
