//
//  FBoardEngine.m
//  BChess
//
//  Created by Jean Bovet on 11/27/17.
//  Copyright © 2017 Jean Bovet. All rights reserved.
//

#import "FEngine.h"
#import "FBoard.hpp"
#import "FPerformance.hpp"
#import "FFEN.hpp"
#import "FTests.hpp"
#import "FMinimax.hpp"

@interface FEngine () {
    Minimax minimax;
    Board currentBoard;
}

@end

@implementation FEngine

- (void)setFEN:(NSString*)boardFEN {
    currentBoard = FFEN::createBoard(std::string([boardFEN UTF8String]));
}

- (NSString*)boardFEN {
    auto fen = FFEN::getFEN(currentBoard);
    return [NSString stringWithUTF8String:fen.c_str()];
}

- (void)move:(NSString*)move {
    // c1b4    
    auto from = [move substringToIndex:2];
    auto to = [move substringFromIndex:2];
    currentBoard.move(std::string([from cStringUsingEncoding:NSUTF8StringEncoding]),
                      std::string([to cStringUsingEncoding:NSUTF8StringEncoding]), WHITE);
}

- (void)stop {
    minimax.analyzing = false;
}

- (FEngineInfo*)infoFor:(Minimax::Info)info {
    FEngineInfo *ei = [[FEngineInfo alloc] init];
    ei.depth = info.depth;
    ei.time = info.time;
    ei.nodeEvaluated = info.nodeEvaluated;
    ei.movesPerSecond = info.movesPerSecond;
    ei.value = info.evaluation.value;
    
    auto bestLine = [NSMutableArray array];
    for (auto move : info.evaluation.line) {
        [bestLine addObject:[NSString stringWithUTF8String:MOVE_DESCRIPTION(move).c_str()]];
    }
    ei.bestLine = bestLine;
    return ei;
}

- (FEngineInfo*)searchBestMove:(NSString*)boardFEN maxDepth:(NSUInteger)maxDepth callback:(FEngineSearchCallback)callback {    
    Board board = FFEN::createBoard(std::string([boardFEN UTF8String]));
    Minimax::Info info = minimax.searchBestMove(board, board.color, (int)maxDepth, [self, callback](Minimax::Info info) {
        callback([self infoFor:info]);
    });
    return [self infoFor:info];
}

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
