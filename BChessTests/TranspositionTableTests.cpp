//
//  TranspositionTableTests.cpp
//  BChessTests
//

#include <gtest/gtest.h>

#include <cstdint>
#include <vector>

#include "ChessEngine.hpp"
#include "FFEN.hpp"

class TranspositionTableTests: public ::testing::Test {
public:
    void SetUp() {
        ChessEngine::initialize();
    }
};

static void put(TranspositionTable &table, int depth, BoardHash hash) {
    table.store(depth, hash, 7, 1, TranspositionEntryType::EXACT);
}

// A table costs no memory until something is stored in it, so that the engines that never search
// (the paste and file probes) are free
TEST_F(TranspositionTableTests, LazyAllocation) {
    TranspositionTable table(4);
    EXPECT_EQ(0u, table.allocatedBytes());
    EXPECT_FALSE(table.exists(12345));
    EXPECT_EQ(0u, table.get(12345).hash);
    
    put(table, 3, 12345);
    size_t bytes = table.allocatedBytes();
    EXPECT_GT(bytes, 0u);
    EXPECT_LE(bytes, 4u * 1024 * 1024);
    EXPECT_EQ(0u, bytes & (bytes - 1)) << "a power of two";
    EXPECT_TRUE(table.exists(12345));
    EXPECT_EQ(3, table.get(12345).depth);
    
    // An engine allocates nothing before its first search
    ChessEngine engine(64);
    EXPECT_EQ(0u, engine.iterativeSearch.table.allocatedBytes());
}

// The table is never cleared, so entries of earlier moves of the game must not block the new ones
TEST_F(TranspositionTableTests, NewSearchReplacesDeeperStaleEntry) {
    TranspositionTable table(1);
    // Two hashes with the same index
    BoardHash a = 5;
    BoardHash b = a + TranspositionTable::entryCountFor(1);
    put(table, 8, a);
    
    // The same search: a shallower entry does not replace a deeper one
    put(table, 2, b);
    EXPECT_TRUE(table.exists(a));
    EXPECT_FALSE(table.exists(b));
    
    // A new search replaces it, whatever its depth
    table.newSearch();
    put(table, 2, b);
    EXPECT_FALSE(table.exists(a));
    EXPECT_TRUE(table.exists(b));
    EXPECT_EQ(2, table.get(b).depth);
}

#ifdef BCHESS_TEST_HOOKS
static int allocatorCalls = 0;
static size_t allocatorCount = 0;
static size_t allocatorSize = 0;

static void *failingAllocator(size_t count, size_t size) {
    allocatorCalls++;
    allocatorCount = count;
    allocatorSize = size;
    return nullptr;
}

// The allocator belongs to the table, so the other searches of the process keep using calloc
static void useFailingAllocator(TranspositionTable &table) {
    allocatorCalls = 0;
    table.allocator = failingAllocator;
}

// No retry on every store, no null dereference, and the search goes on without a table
TEST_F(TranspositionTableTests, FailedAllocationIsHarmless) {
    TranspositionTable table(1);
    useFailingAllocator(table);
    for (int i = 1; i <= 1000; i++) {
        put(table, 3, i);
    }
    EXPECT_EQ(1, allocatorCalls);
    EXPECT_EQ(0u, table.allocatedBytes());
    EXPECT_FALSE(table.exists(1));
    EXPECT_EQ(0u, table.get(1).hash);
    
    ChessBoard board;
    ASSERT_TRUE(FFEN::setFEN("r1bqkbnr/pppp1ppp/2n5/4p3/4P3/5N2/PPPP1PPP/RNBQKB1R w KQkq - 2 3", board));
    MinMaxSearch search;
    search.config.maxDepth = 3;
    search.config.transpositionTable = true;
    MinMaxSearch::Variation pv, bv;
    search.alphabeta(board, NEW_HISTORY, table, 0, true, pv, bv);
    ASSERT_GT(pv.moves.count, 0);
    auto legal = ChessMoveGenerator::generateMoves(board);
    bool found = false;
    for (int i = 0; i < legal.count; i++) {
        found = found || legal.moves[i] == pv.moves.bestMove();
    }
    EXPECT_TRUE(found);
    EXPECT_EQ(1, allocatorCalls);
}

TEST_F(TranspositionTableTests, SizeIsCheckedAndPowerOfTwo) {
    const size_t entry = sizeof(TranspositionEntry);
    EXPECT_EQ(32u, entry);
    EXPECT_EQ(1024u * 1024 / entry, TranspositionTable::entryCountFor(1));
    EXPECT_EQ(1u, TranspositionTable::entryCountFor(0));
    // 3 MB holds 98,304 entries: the largest power of two that fits is 65,536
    EXPECT_EQ(65536u, TranspositionTable::entryCountFor(3));
    
    // One past the largest size in bytes: it wraps to 0 unless it is clamped first
    EXPECT_GT(TranspositionTable::entryCountFor((SIZE_MAX >> 20) + 1), size_t(1) << 30);
    
    // The largest size is clamped, and the byte size of the request does not wrap
    TranspositionTable table(SIZE_MAX);
    useFailingAllocator(table);
    put(table, 1, 1);
    EXPECT_EQ(1, allocatorCalls);
    EXPECT_EQ(entry, allocatorSize);
    EXPECT_EQ(0u, allocatorCount & (allocatorCount - 1)) << "a power of two";
    EXPECT_LE(allocatorCount, SIZE_MAX / entry);
    EXPECT_EQ(allocatorCount * entry / entry, allocatorCount);
    EXPECT_LE(allocatorCount * entry, SIZE_MAX);
    EXPECT_GE(allocatorCount * entry, (SIZE_MAX >> 20 << 20) / 2) << "close to the clamped size, not wrapped to a small one";
    EXPECT_EQ(0u, table.allocatedBytes());
}
#endif
