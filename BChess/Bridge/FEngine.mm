//
//  FBoardEngine.m
//  BChess
//
//  Created by Jean Bovet on 11/27/17.
//  Copyright © 2017 Jean Bovet. All rights reserved.
//

#import "FEngine.h"
#import "FEngineInfo+Private.h"
#import "FEngineMove.h"
#import "FEngineInfo.h"
#import "FEngineUtility.h"
#import "ChessGame.hpp"
#import "ChessBoard.hpp"
#import "FFEN.hpp"
#import "FMove.hpp"
#import "FPGN.hpp"
#import "ChessEngine.hpp"
#import "ChessOpenings.hpp"
#import "IterativeDeepening.hpp"

@interface FEngine () {
    IterativeDeepening<ChessBoard, ChessMoveGenerator, ChessMoveList, ChessEvaluater> iterativeSearch;
    ChessGame currentGame;
    ChessOpenings openings;
}

// This index is used to keep track of which engine session is currently analyzing.
// It is incremented each time the user cancels the current session and is used to
// avoid firing an update if the engine has been cancelled.
@property (nonatomic, assign) NSUInteger stateIndex;

@end

@implementation FEngine

- (id)init {
    if (self = [super init]) {
        _async = YES;
        _thinkingTime = 5;
        _stateIndex = 0;
        ChessMoveGenerator::initialize();
    }
    return self;
}

- (void)fireUpdate:(NSUInteger)localStateIndex {
    dispatch_async(dispatch_get_main_queue(), ^{
        // Do not fire an update if the localStateIndex (which is the one used when
        // the engine started analyzing) is different from the current state index.
        if (self.updateCallback && self.stateIndex == localStateIndex) {
            self.updateCallback();
        }
    });
}

- (BOOL)loadOpening:(NSString* _Nonnull)pgn {
    return openings.load(StringFromNSString(pgn));
}

- (NSDictionary*)openingFor:(NSString *)pgn {
    ChessGame temp;
    if (!FPGN::setGame(StringFromNSString(pgn), temp)) {
        return nil;
    }
    
    NSMutableDictionary *info = [NSMutableDictionary dictionary];
    bool result = openings.lookup(temp.moves, [&](auto & node) {
        info[@"Score"] = @(node.score);
        info[@"Name"] = NSStringFromString(node.name);
        info[@"ECO"] = NSStringFromString(node.eco);
    });
    
    if (result) {
        return info;
    } else {
        return nil;
    }
}

- (BOOL)setFEN:(NSString *)FEN {
    return currentGame.setFEN(StringFromNSString(FEN));
}

- (NSString*)FEN {
    auto fen = currentGame.getFEN();
    return NSStringFromString(fen);
}

- (BOOL)setPGN:(NSString *)PGN {
    return FPGN::setGame(StringFromNSString(PGN), currentGame);
}

- (NSString*)PGN {
    auto pgn = FPGN::getGame(currentGame);
    return NSStringFromString(pgn);
}

- (NSString*)PGNFormattedForDisplay {
    auto pgn = FPGN::getGame(currentGame, FPGN::Formatting::history);
    return NSStringFromString(pgn);
}

- (NSString* _Nullable)pieceAt:(NSUInteger)rank file:(NSUInteger)file {
    BoardSquare square = currentGame.getPieceAt((File)file, (Rank)rank);
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
    NSMutableArray *moves = [NSMutableArray array];
    for (Move move : currentGame.movesAt((File)file, (Rank)rank)) {
        [moves addObject:[self engineMoveFromMove:move]];
    }
    return moves;
}

- (void)move:(NSUInteger)move {
    currentGame.move((Move)move);
    [self fireUpdate:self.stateIndex];
}

- (void)move:(NSString*)from to:(NSString*)to {
    currentGame.move(std::string([from cStringUsingEncoding:NSUTF8StringEncoding]),
                      std::string([to cStringUsingEncoding:NSUTF8StringEncoding]));
    [self fireUpdate:self.stateIndex];
}

- (BOOL)canUndoMove {
    return currentGame.canUndoMove();
}

- (BOOL)canRedoMove {
    return currentGame.canRedoMove();
}

- (void)undoMove {
    // TODO: handle the cancel with a callback when the cancel actually really happened
    [self cancel];
    currentGame.undoMove();
    [self fireUpdate:self.stateIndex];
}

- (void)redoMove {
    [self cancel];
    currentGame.redoMove();
    [self fireUpdate:self.stateIndex];
}

- (void)stop {
    iterativeSearch.stop();
}

- (void)cancel {
    self.stateIndex += 1;
    iterativeSearch.cancel();
}

- (BOOL)isAnalyzing {
    return iterativeSearch.running();
}

- (BOOL)isWhite {
    return currentGame.board.color == WHITE;
}

- (FEngineInfo*)infoFor:(ChessEvaluation)info {
    FEngineInfo *ei = [[FEngineInfo alloc] init];
    ei.info = info;
    ei.game = currentGame;
    return ei;
}

- (void)analyze:(FEngineSearchCallback _Nonnull)callback {
    [self evaluate:INT_MAX time:0 callback:callback];
}

- (void)evaluate:(FEngineSearchCallback _Nonnull)callback {
    [self evaluate:INT_MAX time:self.thinkingTime callback:callback];
}

- (void)evaluate:(NSInteger)depth callback:(FEngineSearchCallback)callback {
    [self evaluate:depth time:0 callback:callback];
}

- (void)evaluate:(NSInteger)depth time:(NSTimeInterval)time callback:(FEngineSearchCallback)callback {
    [self cancel];
    
    NSUInteger localStateIndex = self.stateIndex;
    
    if (self.useOpeningBook) {
        FEngineInfo *info = [self lookupOpeningMove];
        if (info) {
            callback(info, YES);
            [self fireUpdate:localStateIndex];
            return;
        }
    }
    
    if (time > 0) {
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(time * NSEC_PER_SEC)), dispatch_get_global_queue(QOS_CLASS_UTILITY, 0), ^{
            [self stop];
        });
    }

    if (self.async) {
        dispatch_async(dispatch_get_global_queue(QOS_CLASS_USER_INITIATED, 0), ^{
            [self searchBestMove:self.FEN maxDepth:depth callback:^(FEngineInfo * _Nonnull info, BOOL completed) {
                callback(info, completed);
                [self fireUpdate:localStateIndex];
            }];
        });
    } else {
        [self searchBestMove:self.FEN maxDepth:depth callback:^(FEngineInfo * _Nonnull info, BOOL completed) {
            callback(info, completed);
            [self fireUpdate:localStateIndex];
        }];
    }
}

- (FEngineInfo*)lookupOpeningMove {
    FEngineInfo *info = nil;
    bool result = openings.best(currentGame.moves, [&info, self](OpeningTreeNode & node) {
        ChessEvaluation evaluation;
        evaluation.line.push(node.move);
        evaluation.opening = node.name;
        info = [self infoFor:evaluation];
    });
    if (!result) {
        return nil;
    } else {
        return info;
    }
}

- (void)searchBestMove:(NSString*)boardFEN maxDepth:(NSInteger)maxDepth callback:(FEngineSearchCallback)callback {
    ChessBoard board;
    FFEN::setFEN(StringFromNSString(boardFEN), board);
    ChessEvaluation info = iterativeSearch.search(board, (int)maxDepth, [self, callback](ChessEvaluation info) {
        if (!iterativeSearch.cancelled()) {
            callback([self infoFor:info], NO);
        }
    });
    if (!iterativeSearch.cancelled()) {
        callback([self infoFor:info], YES);
    }
}

- (NSArray<NSString*>* _Nonnull)moveFENsFrom:(NSString* _Nonnull)startingFEN squareName:(NSString* _Nullable)squareName {
    auto fen = StringFromNSString(startingFEN);
    ChessBoard board;
    FFEN::setFEN(fen, board);
    std::string boardFEN = FFEN::getFEN(board);
    assert(boardFEN == fen);
    
    Square square;
    if (squareName) {
        square = squareForName(StringFromNSString(squareName));
    } else {
        square = SquareUndefined;
    }
    
    ChessMoveGenerator generator;
    ChessMoveList moves = generator.generateMoves(board, board.color, ChessMoveGenerator::Mode::allMoves, square);
    NSMutableArray<NSString*>* moveFENs = [NSMutableArray array];
    for (int index=0; index<moves.count; index++) {
        auto move = moves.moves[index];
        ChessBoard newBoard = board;
        newBoard.move(move);
        std::string moveFEN = FFEN::getFEN(newBoard);

        [moveFENs addObject:NSStringFromString(moveFEN)];
    }
    return moveFENs;
}

- (void)generatePositions {
    ChessBoard board;
    FFEN::setFEN("3r3k/5Npp/8/8/2Q5/1B6/8/7K b - - 1 1", board);
    
    ChessMoveGenerator generator;
    generator.generateMoves(board);
}

- (void)debugEvaluate {
    currentGame.debugEvaluate();
}

@end
