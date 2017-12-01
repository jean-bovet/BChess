//
//  FBoardEngine.m
//  BChess
//
//  Created by Jean Bovet on 11/27/17.
//  Copyright © 2017 Jean Bovet. All rights reserved.
//

#import "FBoardEngine.h"
#import "FBoard.hpp"
#import "FPerformance.hpp"

@implementation FBoardEngine

- (void)generatePositions {    
    FastMoveGenerator generator;
    Board board;
    generator.generateMoves(board, Color::WHITE);
}

- (void)generatePositions:(int)depth {
    FPerformance performance;
    Board board;
    Color::Color color = Color::WHITE;
    performance.generateMoves(board, color, depth);
    self.moveCount = performance.moveCount;
}

@end
