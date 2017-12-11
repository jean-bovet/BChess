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

@interface FEngine : NSObject

@property (nonatomic, assign) int moveCount;

- (id _Nonnull)init;

- (void)setFEN:(NSString*_Nonnull)boardFEN;
- (NSString* _Nonnull )boardFEN;

- (NSString* _Nullable)pieceAt:(NSUInteger)rank file:(NSUInteger)file;

- (void)move:(NSString*_Nonnull)from to:(NSString*_Nonnull)to;
- (void)stop;

- (FEngineInfo*_Nonnull)searchBestMove:(NSString*_Nonnull)boardFEN
                              maxDepth:(NSInteger)maxDepth
                              callback:(FEngineSearchCallback _Nonnull )callback;

- (NSArray<NSString*>* _Nonnull)moveFENsFrom:(NSString* _Nonnull)startingFEN squareName:(NSString* _Nullable)squareName;

- (void)runTests;
- (void)generatePositions:(int)depth;

@end
