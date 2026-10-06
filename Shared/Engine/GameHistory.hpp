//
//  GameHistory.hpp
//  BChess
//
//  Created by Jean Bovet on 1/6/18.
//  Copyright © 2018 Jean Bovet. All rights reserved.
//

#pragma once

#include "Types.hpp"

#include <atomic>

class ChessHistory {        
public:
#ifdef BCHESS_TEST_HOOKS
    // The history entries that the scans read since the tests last cleared it
    // (atomic: searches on other threads read histories too)
    inline static std::atomic<long> entriesRead{0};
#endif
    
    // Whether `hash`, the last entry of the history, occurred three times on the same side to move. No position
    // before the last pawn move or capture can recur, so the scan stops `reversiblePlies` plies back, see
    // ChessBoard::reversiblePlies. A history shorter than that is scanned whole, and so is any history when
    // reversiblePlies is -1 (unknown).
    static bool isThreefoldRepetition(BoardHash hash, int reversiblePlies, const HistoryPtr &history);
};
