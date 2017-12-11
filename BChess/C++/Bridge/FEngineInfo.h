//
//  FEngineInfo.h
//  BChess
//
//  Created by Jean Bovet on 12/3/17.
//  Copyright © 2017 Jean Bovet. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface FEngineInfo : NSObject

@property (nonatomic, assign) NSUInteger fromRank, fromFile, toRank, toFile;
@property (nonatomic, assign) NSUInteger rawMoveValue;

@property (nonatomic, assign) NSInteger depth;
@property (nonatomic, assign) NSInteger time;
@property (nonatomic, assign) NSInteger nodeEvaluated;
@property (nonatomic, assign) NSInteger movesPerSecond;

@property (nonatomic, assign) NSInteger value;
@property (nonatomic, retain) NSArray<NSString*> *bestLine;

@end
