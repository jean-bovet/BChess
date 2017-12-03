//
//  FEngineInfo.h
//  BChess
//
//  Created by Jean Bovet on 12/3/17.
//  Copyright © 2017 Jean Bovet. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface FEngineInfo : NSObject

@property (nonatomic, assign) NSUInteger depth;
@property (nonatomic, assign) NSUInteger time;
@property (nonatomic, assign) NSUInteger nodeEvaluated;
@property (nonatomic, assign) NSUInteger movesPerSecond;

@property (nonatomic, assign) NSInteger value;
@property (nonatomic, retain) NSArray<NSString*> *bestLine;

@end
