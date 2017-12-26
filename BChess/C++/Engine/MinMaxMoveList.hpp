//
//  MinMaxMoveList.h
//  BChess
//
//  Created by Jean Bovet on 12/25/17.
//  Copyright © 2017 Jean Bovet. All rights reserved.
//

#pragma once

template <class TMove>
struct MinMaxMoveList {
    TMove moves[256];
    int count = 0;
    
    TMove &operator[] (int index) {
        return moves[index];
    }

    void push(TMove move) {
        moves[count] = move;
        count++;
    }
    
    void push(MinMaxMoveList<TMove> line) {
        memcpy(moves+count, line.moves, line.count * sizeof(TMove));
        count += line.count;
    }
    
    void pop() {
        count--;
    }
    
    TMove bestMove() {
        if (count > 0) {
            return moves[0];
        } else {
            return TMove();
        }
    }
};


