//
//  FEngineGame.m
//  BChess
//
//  Created by Jean Bovet on 5/11/21.
//  Copyright © 2021 Jean Bovet. All rights reserved.
//

#import "FEngineGame+Private.h"
#import "FEngineUtility.h"

@implementation FEngineGame

- (instancetype)initWithGame:(ChessGame)game andIndex:(NSUInteger)index {
    if (self = [super init]) {
        self->game = game;
        self.index = index;
        self.name = NSStringFromString(game.tags["White"] + " - " + game.tags["Black"]);
    }
    return self;
}

@end
