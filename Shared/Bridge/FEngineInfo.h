//
//  FEngineInfo.h
//  BChess
//
//  Created by Jean Bovet on 12/3/17.
//  Copyright © 2017 Jean Bovet. All rights reserved.
//

#import <Foundation/Foundation.h>

@class FEngineMove;

/** Immutable once the engine has handed it out. */
NS_SWIFT_SENDABLE
@interface FEngineInfo : NSObject

@property (nonatomic, assign, readonly) NSUInteger fromRank, fromFile, toRank, toFile;

// NO when the search found no move (a mate, a stalemate or a drawn position)
@property (nonatomic, assign, readonly) BOOL hasBestMove;
@property (nonatomic, assign, readonly) NSUInteger bestMove;
@property (nonatomic, strong, readonly) FEngineMove * _Nullable bestEngineMove;

@property (nonatomic, assign, readonly) BOOL mat;
// The number of plies to the mate when `mat`, 0 otherwise
@property (nonatomic, assign, readonly) NSInteger matePlies;
@property (nonatomic, assign, readonly) BOOL isWhite;

@property (nonatomic, assign, readonly) NSInteger depth;
@property (nonatomic, assign, readonly) NSInteger quiescenceDepth;
// The deepest ply the search visited
@property (nonatomic, assign, readonly) NSInteger selDepth;
// Milliseconds since the search started, and the nodes and nodes per second of the whole search
@property (nonatomic, assign, readonly) NSInteger time;
@property (nonatomic, assign, readonly) NSInteger nodeEvaluated;
@property (nonatomic, assign, readonly) NSInteger movesPerSecond;

@property (nonatomic, assign, readonly) NSInteger value;

- (NSString* _Nullable)bestMove:(BOOL)uci;
- (NSString* _Nonnull)bestLine:(BOOL)uci;

@end
