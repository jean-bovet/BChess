//
//  FBoardEngine.h
//  BChess
//
//  Created by Jean Bovet on 11/27/17.
//  Copyright © 2017 Jean Bovet. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "FEngineInfo.h"

typedef void(^FEngineSearchCallback)(FEngineInfo * _Nonnull info, BOOL completed);
typedef void(^FEngineDidUpdateCallback)();

@interface FEngineMove: NSObject

@property (nonatomic, assign) NSUInteger fromFile, toFile;
@property (nonatomic, assign) NSUInteger fromRank, toRank;
@property (nonatomic, assign) NSUInteger rawMoveValue;

@end

@interface FEngine : NSObject

@property (nonatomic, assign) int moveCount;
@property (nonatomic, assign) BOOL async;

@property (nonatomic, strong) FEngineDidUpdateCallback _Nullable updateCallback;

- (id _Nonnull)init;

- (BOOL)setFEN:(NSString* _Nonnull)FEN;
- (NSString* _Nonnull)FEN;

- (BOOL)setPGN:(NSString* _Nonnull)PGN;
- (NSString* _Nonnull)PGN;

- (NSString* _Nonnull)PGNFormattedForDisplay;

- (NSString* _Nullable)pieceAt:(NSUInteger)rank file:(NSUInteger)file;

- (NSArray<FEngineMove*>* _Nonnull)movesAt:(NSUInteger)rank file:(NSUInteger)file;
- (void)move:(NSUInteger)move;

- (BOOL)canUndoMove;
- (BOOL)canRedoMove;

- (void)undoMove;
- (void)redoMove;

- (void)move:(NSString* _Nonnull)from to:(NSString* _Nonnull)to;
- (void)stop;

- (BOOL)isWhite;

- (void)evaluate:(NSInteger)depth callback:(FEngineSearchCallback _Nonnull)callback;

- (NSArray<NSString*>* _Nonnull)moveFENsFrom:(NSString* _Nonnull)startingFEN squareName:(NSString* _Nullable)squareName;

- (void)generatePositions:(int)depth;

- (void)debugEvaluate;

@end
