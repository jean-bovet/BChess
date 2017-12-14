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

@implementation FEngineMove

@end

@interface FEngine () {
    Minimax minimax;
    Board currentBoard;
}

@property (nonatomic, strong) NSMutableArray<FEngineMove*> *moves;
@property (nonatomic, assign) NSUInteger moveCursor;

@end

@implementation FEngine

- (id)init {
    if (self = [super init]) {
        MoveGenerator::initialize();
        _moves = [NSMutableArray array];
        _moveCursor = 0;
        _async = YES;
    }
    return self;
}

- (void)fireUpdate {
    dispatch_async(dispatch_get_main_queue(), ^{
        if (self.updateCallback) {
            self.updateCallback();
        }
    });
}

- (void)setFEN:(NSString *)FEN {
    FFEN::setFEN(std::string([FEN UTF8String]), currentBoard);
}

- (NSString*)FEN {
    auto fen = FFEN::getFEN(currentBoard);
    return [NSString stringWithUTF8String:fen.c_str()];
}

- (NSString* _Nullable)pieceAt:(NSUInteger)rank file:(NSUInteger)file {
    BoardSquare square = currentBoard.get((File)file, (Rank)rank);
    if (square.empty) {
        return nil;
    } else {
        char p = pieceToChar(square.piece, square.color == WHITE);
        return [NSString stringWithFormat:@"%c", p];
    }
}

- (FEngineMove*)engineMoveFromMove:(Move)fmove {
    FEngineMove *move = [[FEngineMove alloc] init];
    move.rawMoveValue = fmove;
    move.fromFile = FileFrom(MOVE_FROM(fmove));
    move.fromRank = RankFrom(MOVE_FROM(fmove));
    move.toFile = FileFrom(MOVE_TO(fmove));
    move.toRank = RankFrom(MOVE_TO(fmove));
    return move;
}

- (NSArray<FEngineMove*>* _Nonnull)movesAt:(NSUInteger)rank file:(NSUInteger)file {
    MoveGenerator generator = MoveGenerator();
    MoveList moveList = generator.generateMoves(currentBoard, SquareFrom((File)file, (Rank)rank));
    
    NSMutableArray *moves = [NSMutableArray array];
    for (int index=0; index<moveList.moveCount; index++) {
        Move fmove = moveList.moves[index];
        [moves addObject:[self engineMoveFromMove:fmove]];
    }
    return moves;
}

- (void)move:(NSUInteger)move {
    if (self.moveCursor < self.moves.count) {
        // Clear the rest of the history
        [self.moves removeObjectsInRange:NSMakeRange(self.moveCursor, self.moves.count - self.moveCursor)];
    }
    
    [self.moves addObject:[self engineMoveFromMove:(Move)move]];
    self.moveCursor = self.moves.count;
    
    currentBoard.move((Move)move);
    
    [self fireUpdate];
}

- (void)move:(NSString*)from to:(NSString*)to {
    // TODO: when is that one used? We need to keep track of move for the history
    currentBoard.move(std::string([from cStringUsingEncoding:NSUTF8StringEncoding]),
                      std::string([to cStringUsingEncoding:NSUTF8StringEncoding]));
}

- (BOOL)canUndoMove {
    return self.moveCursor > 0;
}

- (BOOL)canRedoMove {
    return self.moveCursor < self.moves.count;
}

- (void)undoMove {
    if (self.moveCursor > 0) {
        self.moveCursor--;
        [self replayMoves];
    }
}

- (void)redoMove {
    if (self.moveCursor < self.moves.count) {
        self.moveCursor++;
        [self replayMoves];
    }
}

- (void)replayMoves {
    currentBoard.reset();
    for (NSUInteger index=0; index<self.moveCursor; index++) {
        FEngineMove *move = self.moves[index];
        currentBoard.move((Move)move.rawMoveValue);
    }
    [self fireUpdate];
}

- (void)stop {
    minimax.analyzing = false;
}

- (BOOL)isWhite {
    return currentBoard.color == WHITE;
}

- (FEngineInfo*)infoFor:(Minimax::Info)info {
    FEngineInfo *ei = [[FEngineInfo alloc] init];
    ei.depth = info.depth;
    ei.time = info.time;
    ei.nodeEvaluated = info.nodeEvaluated;
    ei.movesPerSecond = info.movesPerSecond;
    ei.rawMoveValue = info.evaluation.move;
    ei.mat = info.evaluation.mat;
    ei.fromRank = RankFrom(MOVE_FROM(info.evaluation.move));
    ei.fromFile = FileFrom(MOVE_FROM(info.evaluation.move));
    ei.toRank = RankFrom(MOVE_TO(info.evaluation.move));
    ei.toFile = FileFrom(MOVE_TO(info.evaluation.move));

    // For UCI, the value is always from the engine's point of view.
    // Because the evaluation function always evaluate from WHITE's point of view,
    // if the engine is playing black, make sure to inverse the value.
    if (info.engineColor == BLACK) {
        ei.value = -info.evaluation.value;
    } else {
        ei.value = info.evaluation.value;
    }
    
    auto bestLine = [NSMutableArray array];
    for (auto move : info.evaluation.line) {
        [bestLine addObject:[NSString stringWithUTF8String:MOVE_DESCRIPTION(move).c_str()]];
    }
    ei.bestLine = bestLine;
    return ei;
}

- (void)evaluate:(NSInteger)depth callback:(FEngineSearchCallback)callback {
    [self stop];
    
    if (self.async) {
        dispatch_async(dispatch_get_global_queue(QOS_CLASS_BACKGROUND, 0), ^{
            [self searchBestMove:self.FEN maxDepth:depth callback:^(FEngineInfo * _Nonnull info, BOOL completed) {
                callback(info, completed);
                [self fireUpdate];
            }];
        });
    } else {
        [self searchBestMove:self.FEN maxDepth:depth callback:^(FEngineInfo * _Nonnull info, BOOL completed) {
            callback(info, completed);
            [self fireUpdate];
        }];
    }
}

- (void)searchBestMove:(NSString*)boardFEN maxDepth:(NSInteger)maxDepth callback:(FEngineSearchCallback)callback {
    Board board;
    FFEN::setFEN(std::string([boardFEN UTF8String]), board);
    Minimax::Info info = minimax.searchBestMove(board, (int)maxDepth, [self, callback](Minimax::Info info) {
        callback([self infoFor:info], NO);
    });
    callback([self infoFor:info], YES);
}

- (NSArray<NSString*>* _Nonnull)moveFENsFrom:(NSString* _Nonnull)startingFEN squareName:(NSString* _Nullable)squareName {
    auto fen = std::string([startingFEN UTF8String]);
    Board board;
    FFEN::setFEN(fen, board);
    std::string boardFEN = FFEN::getFEN(board);
    assert(boardFEN == fen);
    
    Square square;
    if (squareName) {
        square = squareForName(std::string([squareName UTF8String]));
    } else {
        square = SquareUndefined;
    }
    
    MoveGenerator generator;
    MoveList moves = generator.generateMoves(board, square);
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
    Board board;
    FFEN::setFEN("3r3k/5Npp/8/8/2Q5/1B6/8/7K b - - 1 1", board);
    
    MoveGenerator generator;
    generator.generateMoves(board, Color::WHITE);
}

- (void)generatePositions:(int)depth {
    FPerformance performance;
    Board board;
    performance.generateMoves(board, depth);
    self.moveCount = performance.moveCount;
}

@end
