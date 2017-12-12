//
//  FBoardEngine.h
//  BChess
//
//  Created by Jean Bovet on 11/27/17.
//  Copyright © 2017 Jean Bovet. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "FEngineInfo.h"

typedef void(^FEngineSearchCallback)(FEngineInfo * _Nonnull info);

@interface FEngineMove: NSObject

@property (nonatomic, assign) NSUInteger fromFile, toFile;
@property (nonatomic, assign) NSUInteger fromRank, toRank;
@property (nonatomic, assign) NSUInteger rawMoveValue;

@end

@interface FEngine : NSObject

@property (nonatomic, assign) int moveCount;

- (id _Nonnull)init;

- (void)setFEN:(NSString*_Nonnull)boardFEN;
- (NSString* _Nonnull )boardFEN;

- (NSString* _Nullable)pieceAt:(NSUInteger)rank file:(NSUInteger)file;

- (NSArray<FEngineMove*>* _Nonnull)movesAt:(NSUInteger)rank file:(NSUInteger)file;
- (void)move:(NSUInteger)move;

- (void)move:(NSString*_Nonnull)from to:(NSString*_Nonnull)to;
- (void)stop;

- (BOOL)isWhite;

- (FEngineInfo*_Nonnull)searchBestMove:(NSString*_Nonnull)boardFEN
                              maxDepth:(NSInteger)maxDepth
                              callback:(FEngineSearchCallback _Nonnull )callback;

- (NSArray<NSString*>* _Nonnull)moveFENsFrom:(NSString* _Nonnull)startingFEN squareName:(NSString* _Nullable)squareName;

- (void)runTests;
- (void)generatePositions:(int)depth;

@end
