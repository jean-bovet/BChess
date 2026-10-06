//
//  FEngine+Testing.h
//  BChess
//
//  Hooks for tests only. Imported by the test bridging header, never by the app or the UCI tool.
//

#import "FEngine.h"

NS_ASSUME_NONNULL_BEGIN

@interface FEngine (Testing)

/** Runs the block on the engine's serial search queue, behind any search that is queued or running. */
- (void)performOnSearchQueue:(dispatch_block_t)block;

/** The memory the transposition table holds now: 0 before the first search stores anything. Waits for the
 search queue. */
- (NSUInteger)transpositionTableBytes;

/** The table size in megabytes that the engine takes on a phone or on a Mac. The platform is chosen at compile
 time, and the iOS scheme runs UI tests only, so both values are checked from here. */
+ (NSUInteger)hashMegabytesForPhone:(BOOL)phone;

/** Called inside the search, right after a move has been pushed on the search's history. Takes effect
 only in builds that define BCHESS_TEST_HOOKS. Pass nil to remove it. */
- (void)setSearchCheckpoint:(nullable dispatch_block_t)block;

@end

NS_ASSUME_NONNULL_END
