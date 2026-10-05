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

/** Called inside the search, right after a move has been pushed on the search's history. Takes effect
 only in builds that define BCHESS_TEST_HOOKS. Pass nil to remove it. */
- (void)setSearchCheckpoint:(nullable dispatch_block_t)block;

@end

NS_ASSUME_NONNULL_END
