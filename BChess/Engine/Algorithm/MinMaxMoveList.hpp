//
//  MinMaxMoveList.h
//  BChess
//
//  Created by Jean Bovet on 12/25/17.
//  Copyright © 2017 Jean Bovet. All rights reserved.
//

#pragma once

#include <cassert>
#include "FMove.hpp"

const int MAX_MOVES = 256;

struct MinMaxMoveList {
    Move moves[MAX_MOVES];
    int count = 0;
    
    Move &operator[] (int index) {
        assert(index < MAX_MOVES);
        assert(index < count);
        return moves[index];
    }

    void push(Move move) {
        assert(count < MAX_MOVES);
        moves[count] = move;
        count++;
    }
    
    void push(MinMaxMoveList line) {
        assert(count+line.count < MAX_MOVES);
        memcpy(moves+count, line.moves, line.count * sizeof(Move));
        count += line.count;
    }
    
    void pop() {
        assert(count > 0);
        count--;
    }
    
    Move lookup(int index) {
        if (index < count) {
            return moves[index];
        } else {
            return INVALID_MOVE;
        }
    }
    
    Move bestMove() {
        if (count > 0) {
            return moves[0];
        } else {
            return INVALID_MOVE;
        }
    }
};


