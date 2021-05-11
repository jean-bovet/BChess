//
//  FBoardEngine.h
//  BChess
//
//  Created by Jean Bovet on 11/27/17.
//  Copyright © 2017 Jean Bovet. All rights reserved.
//

#import <Foundation/Foundation.h>

@class FEngineMove;
@class FEngineInfo;
@class FEngineMoveNode;

typedef void(^FEngineSearchCallback)(FEngineInfo * _Nonnull info, BOOL completed);
typedef void(^FEngineDidUpdateCallback)();

/** This class is the interface between the C++ engine and the Objective-C/Swift world*/
@interface FEngine : NSObject

@property (nonatomic, assign) BOOL async;
@property (nonatomic, assign) BOOL useOpeningBook;
@property (nonatomic, assign) BOOL positionalAnalysis;
@property (nonatomic, assign) BOOL ttEnabled;
@property (nonatomic, assign) NSUInteger searchDepth;
@property (nonatomic, assign) NSTimeInterval thinkingTime;

@property (nonatomic, strong) FEngineDidUpdateCallback _Nullable updateCallback;

@property (nonatomic, strong, readonly) NSString * _Nonnull state;

- (id _Nonnull)init;

- (BOOL)loadOpening:(NSString* _Nonnull)pgn;
- (BOOL)isValidOpeningMoves;
- (NSString* _Nullable)openingName;

- (BOOL)setFEN:(NSString* _Nonnull)FEN;
- (NSString* _Nonnull)FEN;

- (BOOL)setPGN:(NSString* _Nonnull)PGN;
- (NSString* _Nonnull)PGN;

- (NSString* _Nonnull)PGNFormattedForDisplay;
- (NSArray<FEngineMoveNode*>* _Nonnull)moveNodesTree;

- (NSArray<FEngineMove*>* _Nonnull)allMoves;
- (NSArray<FEngineMove*>* _Nonnull)movesAt:(NSUInteger)rank file:(NSUInteger)file;
- (void)move:(NSUInteger)move;

- (BOOL)canUndoMove;
- (BOOL)canRedoMove;

- (void)undoMove;
- (void)redoMove;

- (void)move:(NSString* _Nonnull)from to:(NSString* _Nonnull)to;

// This stops the current search and return the best result so far. This is used
// when the time alloted to think has expired.
- (void)stop;

// This stops the current search but does not return anything. This is used
// to cancel what's happening without affecting the current game.
- (void)cancel;

- (BOOL)isAnalyzing;

- (BOOL)isWhite;

- (BOOL)canPlay;

- (void)analyze:(FEngineSearchCallback _Nonnull)callback;

- (void)evaluate:(FEngineSearchCallback _Nonnull)callback;
- (void)evaluate:(NSInteger)depth callback:(FEngineSearchCallback _Nonnull)callback;
- (void)evaluate:(NSInteger)depth time:(NSTimeInterval)time callback:(FEngineSearchCallback _Nonnull)callback;

@end
