//
//  GameHistory.cpp
//  BChess
//
//  Created by Jean Bovet on 1/6/18.
//  Copyright © 2018 Jean Bovet. All rights reserved.
//

#include "GameHistory.hpp"

// See https://chess.stackexchange.com/questions/17127/programming-the-three-fold-repetition-for-my-chess-engine
bool ChessHistory::isThreefoldRepetition(BoardHash hash, int reversiblePlies, const HistoryPtr &history) {
    long last = (long)history->size() - 1;
    long oldest = 0;
    if (reversiblePlies >= 0 && reversiblePlies < last) {
        oldest = last - reversiblePlies;
    }
    int count = 0;
    for (long index=last; index>=oldest; index -= 2) {
#ifdef BCHESS_TEST_HOOKS
        entriesRead++;
#endif
        if (history->at(index) == hash) {
            count++;
            if (count >= 3) {
                return true;
            }
        }
    }
    return false;
}
