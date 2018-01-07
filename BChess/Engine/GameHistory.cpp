//
//  GameHistory.cpp
//  BChess
//
//  Created by Jean Bovet on 1/6/18.
//  Copyright © 2018 Jean Bovet. All rights reserved.
//

#include "GameHistory.hpp"

// See https://chess.stackexchange.com/questions/17127/programming-the-three-fold-repetition-for-my-chess-engine
bool ChessHistory::isThreefoldRepetition(BoardHash hash, HistoryPtr history) {
    int count = 0;
    for (long index=history->size()-1; index>=0; index -= 2) {
        if (history->at(index) == hash) {
            count++;
            if (count >= 3) {
                return true;
            }
        }
    }
    return false;
}
