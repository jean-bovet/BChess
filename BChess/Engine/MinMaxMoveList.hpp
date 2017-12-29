//
//  MinMaxMoveList.h
//  BChess
//
//  Created by Jean Bovet on 12/25/17.
//  Copyright © 2017 Jean Bovet. All rights reserved.
//

#pragma once

const int MAX_MOVES = 256;

template <class TMove>
struct MinMaxMoveList {
    TMove moves[MAX_MOVES];
    int count = 0;
    
    TMove &operator[] (int index) {
        assert(index < MAX_MOVES);
        assert(index < count);
        return moves[index];
    }

    void push(TMove move) {
        assert(count < MAX_MOVES);
        moves[count] = move;
        count++;
    }
    
    void push(MinMaxMoveList<TMove> line) {
        assert(count+line.count < MAX_MOVES);
        memcpy(moves+count, line.moves, line.count * sizeof(TMove));
        count += line.count;
    }
    
    void pop() {
        assert(count > 0);
        count--;
    }
    
    TMove lookup(int index) {
        if (index < count) {
            return moves[index];
        } else {
            return TMove();
        }
    }
    
    TMove bestMove() {
        if (count > 0) {
            return moves[0];
        } else {
            return TMove();
        }
    }
};


