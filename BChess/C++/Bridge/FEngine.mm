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
#import "FMove.hpp"
#import "FTests.hpp"
#import "FMinimax.hpp"

@interface FEngine () {
    Minimax minimax;
    Board currentBoard;
}

@end

@implementation FEngine

- (id)init {
    if (self = [super init]) {
        MoveGenerator::initialize();
    }
    return self;
}

- (void)setFEN:(NSString*)boardFEN {
    currentBoard = FFEN::createBoard(std::string([boardFEN UTF8String]));
}

- (NSString*)boardFEN {
    auto fen = FFEN::getFEN(currentBoard);
    return [NSString stringWithUTF8String:fen.c_str()];
}

- (void)move:(NSString*)from to:(NSString*)to {
    currentBoard.move(std::string([from cStringUsingEncoding:NSUTF8StringEncoding]),
                      std::string([to cStringUsingEncoding:NSUTF8StringEncoding]));
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

- (FEngineInfo*)searchBestMove:(NSString*)boardFEN maxDepth:(NSInteger)maxDepth callback:(FEngineSearchCallback)callback {
    Board board = FFEN::createBoard(std::string([boardFEN UTF8String]));
    Minimax::Info info = minimax.searchBestMove(board, (int)maxDepth, [self, callback](Minimax::Info info) {
        callback([self infoFor:info]);
    });
    return [self infoFor:info];
}

- (NSArray<NSString*>* _Nonnull)moveFENsFrom:(NSString* _Nonnull)startingFEN squareName:(NSString* _Nullable)squareName {
    auto fen = std::string([startingFEN UTF8String]);
    Board board = FFEN::createBoard(fen);
    std::string boardFEN = FFEN::getFEN(board);
    assert(boardFEN == fen);
    
    int squareIndex;
    if (squareName) {
        auto square = std::string([squareName UTF8String]);
        squareIndex = squareIndexForName(square);
    } else {
        squareIndex = -1;
    }
    
    MoveGenerator generator;
    MoveList moves = generator.generateMoves(board, squareIndex);
    NSMutableArray<NSString*>* moveFENs = [NSMutableArray array];
    for (int index=0; index<moves.moveCount; index++) {
        auto move = moves.moves[index];

        Board newBoard = board;
        newBoard.move(move);
        std::string moveFEN = FFEN::getFEN(newBoard);

        [moveFENs addObject:[NSString stringWithUTF8String:moveFEN.c_str()]];
    }
    return moveFENs;
}

- (void)runTests {
    FTests::runAll();
}

- (void)generatePositions {
    FFEN::createBoard("3r3k/5Npp/8/8/2Q5/1B6/8/7K b - - 1 1");
    
    MoveGenerator generator;
    Board board;
    generator.generateMoves(board, Color::WHITE);
}

- (void)generatePositions:(int)depth {
    FPerformance performance;
    Board board;
    performance.generateMoves(board, depth);
    self.moveCount = performance.moveCount;
}

@end
