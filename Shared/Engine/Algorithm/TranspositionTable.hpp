//
//  TranspositionTable.hpp
//  BChess
//
//  Created by Jean Bovet on 1/21/18.
//  Copyright © 2018 Jean Bovet. All rights reserved.
//

#pragma once

#include <cstdint>
#include <cstdlib>
#include <string>

#include "Types.hpp"
#include "Move.hpp"

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
    // The search that stored it, see TranspositionTable::newSearch()
    uint8_t generation;
#ifdef ASSERT_TT_KEY_COLLISION
    std::string shortFEN;
#endif
};

// The table allocates nothing until the first store, so an engine that never searches costs no memory. The size
// is a power of two number of entries that fits in `megabytes`. When the allocation fails, the table stays
// empty for its whole life: stores and probes return at once, and the search works without it.
class TranspositionTable {
    TranspositionEntry *table = nullptr;
    size_t megabytes;
    size_t entryCount = 0;
    size_t mask = 0;
    bool allocationFailed = false;
    uint8_t generation = 0;
    
    static void *allocate(size_t count, size_t size) {
#ifdef BCHESS_TEST_HOOKS
        return allocator(count, size);
#else
        return calloc(count, size);
#endif
    }
    
    // Called by the first store only
    void allocateTable() {
        size_t count = entryCountFor(megabytes);
        table = (TranspositionEntry*)allocate(count, sizeof(TranspositionEntry));
        if (table) {
            entryCount = count;
            mask = count - 1;
        } else {
            allocationFailed = true;
        }
    }
    
public:
    
#ifdef BCHESS_TEST_HOOKS
    // The allocation, replaceable by a test that wants it to fail or to see the size requested
    inline static void *(*allocator)(size_t count, size_t size) = calloc;
#endif
    
    bool enabled = true;

    int storeCount = 0;
    int collisionCount = 0;
    int newStoreCount = 0;
    
    explicit TranspositionTable(size_t sizeMegabytes = 16) : megabytes(sizeMegabytes) {
    }
    
    ~TranspositionTable() {
        free(table);
    }
    
    TranspositionTable(const TranspositionTable &) = delete;
    TranspositionTable &operator=(const TranspositionTable &) = delete;
    
    // The largest power of two number of entries that fits in `megabytes`, at least 1. The byte size is
    // computed so that it cannot overflow: the megabytes are clamped first, and the count is at most size/entry.
    static size_t entryCountFor(size_t megabytes) {
        const size_t maxMegabytes = SIZE_MAX >> 20;
        if (megabytes > maxMegabytes) {
            megabytes = maxMegabytes;
        }
        size_t maxEntries = (megabytes << 20) / sizeof(TranspositionEntry);
        size_t count = 1;
        while (count <= maxEntries / 2) {
            count <<= 1;
        }
        return count;
    }
    
    size_t allocatedBytes() const {
        return table ? entryCount * sizeof(TranspositionEntry) : 0;
    }
    
    // Starts a new search: an entry that an earlier search stored can then be replaced whatever its depth, so
    // that the table does not fill up with deep entries of earlier moves of the game
    void newSearch() {
        generation++;
    }
    
    void store(int depth, BoardHash hash, int value, Move bestMove, TranspositionEntryType type
#ifdef ASSERT_TT_KEY_COLLISION
               , std::string shortFEN
#endif
               ) {
        if (!table) {
            if (allocationFailed) {
                return;
            }
            allocateTable();
            if (!table) {
                return;
            }
        }
        size_t index = hash & mask;
        storeCount++;
        if (table[index].generation != generation || depth >= table[index].depth) {
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
            table[index].generation = generation;
#ifdef ASSERT_TT_KEY_COLLISION
            table[index].shortFEN = shortFEN;
#endif
        }
    }
    
    // An empty entry (hash 0) when nothing is allocated
    TranspositionEntry get(BoardHash hash) {
        if (!table) {
            return TranspositionEntry();
        }
        return table[hash & mask];
    }
    
    bool exists(BoardHash hash
#ifdef ASSERT_TT_KEY_COLLISION
                , std::string shortFEN
#endif
                ) {
        if (!table) {
            return false;
        }
        size_t index = hash & mask;
        if (table[index].hash == hash) {
#ifdef ASSERT_TT_KEY_COLLISION
            assert(table[index].shortFEN == shortFEN);
#endif
            return true;
        } else {
            return false;
        }
    }
};
