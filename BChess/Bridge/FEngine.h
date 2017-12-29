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

typedef enum : NSUInteger {
    Easy,
    Medium,
    Hard,
} Level;

@interface FEngineMove: NSObject

@property (nonatomic, assign) NSUInteger fromFile, toFile;
@property (nonatomic, assign) NSUInteger fromRank, toRank;
@property (nonatomic, assign) NSUInteger rawMoveValue;
@property (nonatomic, assign, readonly) BOOL isPromotion;

- (void)setPromotionPiece:(NSString* _Nonnull)piece;

@end

@interface FEngine : NSObject

@property (nonatomic, assign) int moveCount;
@property (nonatomic, assign) BOOL async;
@property (nonatomic, assign) BOOL useOpeningBook;
@property (nonatomic, assign) Level level;

@property (nonatomic, strong) FEngineDidUpdateCallback _Nullable updateCallback;

- (id _Nonnull)init;

- (BOOL)loadOpening:(NSString* _Nonnull)pgn;

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
- (BOOL)isAnalyzing;

- (BOOL)isWhite;

- (void)analyze:(FEngineSearchCallback _Nonnull)callback;

- (void)evaluate:(FEngineSearchCallback _Nonnull)callback;
- (void)evaluate:(NSInteger)depth callback:(FEngineSearchCallback _Nonnull)callback;
- (void)evaluate:(NSInteger)depth time:(NSTimeInterval)time callback:(FEngineSearchCallback _Nonnull)callback;

- (NSArray<NSString*>* _Nonnull)moveFENsFrom:(NSString* _Nonnull)startingFEN squareName:(NSString* _Nullable)squareName;

- (void)debugEvaluate;

@end
