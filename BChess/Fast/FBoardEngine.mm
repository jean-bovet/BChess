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
#import "FFEN.hpp"
#import "FTests.hpp"

@implementation FBoardEngine

- (void)runTests {
    FTests::runAll();
}

- (void)generatePositions {
    FFEN::createBoard("3r3k/5Npp/8/8/2Q5/1B6/8/7K b - - 1 1");
    
    FastMoveGenerator generator;
    Board board;
    generator.generateMoves(board, Color::WHITE);
}

- (void)generatePositions:(int)depth {
    FPerformance performance;
    Board board;
    Color color = Color::WHITE;
    performance.generateMoves(board, color, depth);
    self.moveCount = performance.moveCount;
}

@end
