//
//  FBoardEngine.m
//  BChess
//
//  Created by Jean Bovet on 11/27/17.
//  Copyright © 2017 Jean Bovet. All rights reserved.
//

#import "FBoardEngine.h"
#import "FBoard.hpp"

@implementation FBoardEngine

- (void)generatePositions {
    FastMoveGenerator generator;
    Board board;
    generator.generateMoves(board, Color::WHITE);
}

@end
