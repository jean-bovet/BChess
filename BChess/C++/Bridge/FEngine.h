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

- (void)setFEN:(NSString*_Nonnull)boardFEN;
- ( NSString* _Nonnull )boardFEN;

- (void)move:(NSString*_Nonnull)move;
- (void)stop;

- (FEngineInfo*_Nonnull)searchBestMove:(NSString*_Nonnull)boardFEN maxDepth:(NSUInteger)maxDepth callback:(FEngineSearchCallback _Nonnull )callback;

- (void)runTests;
- (void)generatePositions;
- (void)generatePositions:(int)depth;

@end
