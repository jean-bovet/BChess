//
//  FEngineGame+Private.m
//  BChess
//
//  Created by Jean Bovet on 5/11/21.
//  Copyright © 2021 Jean Bovet. All rights reserved.
//

#import "FEngineGame.h"
#import "ChessGame.hpp"

@interface FEngineGame () {
    ChessGame game;
}

@property (nonatomic, assign, readwrite) NSUInteger index;
@property (nonatomic, strong, readwrite) NSString * _Nonnull name;

- (instancetype _Nonnull )initWithGame:(ChessGame)game andIndex:(NSUInteger)index;

@end
