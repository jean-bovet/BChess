//
//  FEngineInfo.h
//  BChess
//
//  Created by Jean Bovet on 12/3/17.
//  Copyright © 2017 Jean Bovet. All rights reserved.
//

#import <Foundation/Foundation.h>

@class FEngineMove;

@interface FEngineInfo : NSObject

@property (nonatomic, assign, readonly) NSUInteger fromRank, fromFile, toRank, toFile;

@property (nonatomic, assign, readonly) NSUInteger bestMove;
@property (nonatomic, strong, readonly) FEngineMove * _Nullable bestEngineMove;

@property (nonatomic, assign, readonly) BOOL mat;
@property (nonatomic, assign, readonly) BOOL isWhite;

@property (nonatomic, assign, readonly) NSInteger depth;
@property (nonatomic, assign, readonly) NSInteger quiescenceDepth;
@property (nonatomic, assign, readonly) NSInteger time;
@property (nonatomic, assign, readonly) NSInteger nodeEvaluated;
@property (nonatomic, assign, readonly) NSInteger movesPerSecond;

@property (nonatomic, assign, readonly) NSInteger value;

- (NSString* _Nullable)bestMove:(BOOL)uci;
- (NSString* _Nonnull)bestLine:(BOOL)uci;

@end
