//
//  TranspositionTable.hpp
//  BChess
//
//  Created by Jean Bovet on 1/21/18.
//  Copyright © 2018 Jean Bovet. All rights reserved.
//

#pragma once

#include "Types.hpp"
#include "FMove.hpp"

#define TRANSPO_SIZE (size_t)(18*1000*1000)

enum TranspositionEntryType {
    /**
     Exact evaluation, when we receive a definite evaluation, that is we searched all possible moves and
     received a new best move (or received an evaluation from quiescent search that was between alpha and beta). */
    EXACT,
    
    /** Alpha Evaluation, when we do not reach up to alpha. We only know that the evaluation was not as high as alpha.
     */
    ALPHA,
    
    /** Beta evaluation, when we exceed beta we know the move is 'too good' and cut off the rest of the search.
     Since some of the search is cut off we do not know what the actual evaluation of the position was.
     All we know is it was at least 'beta' or higher.
     */
    BETA
};

struct TranspositionEntry {
    int depth;
    BoardHash hash;
    int value;
    Move bestMove;
    TranspositionEntryType type;
#ifdef ASSERT_TT_KEY_COLLISION
    std::string shortFEN;
#endif
};

class TranspositionTable {
    TranspositionEntry *table = nullptr;
    
public:
    
    bool enabled = true;

    int storeCount = 0;
    int collisionCount = 0;
    int newStoreCount = 0;
    
    TranspositionTable() {
        table = (TranspositionEntry*)calloc(TRANSPO_SIZE+1, sizeof(TranspositionEntry));
    }
    
    ~TranspositionTable() {
        free(table);
    }
    
    void store(int depth, BoardHash hash, int value, Move bestMove, TranspositionEntryType type
#ifdef ASSERT_TT_KEY_COLLISION
               , std::string shortFEN
#endif
               ) {
        unsigned long index = hash % TRANSPO_SIZE;
        storeCount++;
        if (depth >= table[index].depth) {
            if (table[index].hash != 0) {
                // Collision?
                if (table[index].hash != hash) {
                    collisionCount++;
                } else {
                    // Replacement
                }
            } else {
                newStoreCount++;
            }
            table[index].depth = depth;
            table[index].hash = hash;
            table[index].value = value;
            table[index].bestMove = bestMove;
            table[index].type = type;
#ifdef ASSERT_TT_KEY_COLLISION
            table[index].shortFEN = shortFEN;
#endif
        }
    }
    
    TranspositionEntry get(BoardHash hash) {
        int index = hash % TRANSPO_SIZE;
        return table[index];
    }
    
    bool exists(BoardHash hash
#ifdef ASSERT_TT_KEY_COLLISION
                std::string shortFEN
#endif
                ) {
        int index = hash % TRANSPO_SIZE;
        if (table[index].hash == hash) {
#ifdef ASSERT_TT_KEY_COLLISION
            assert(table[index].shortFEN != shortFEN);
#endif
            return true;
        } else {
            return false;
        }
    }
};
