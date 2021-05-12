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
#import "FEngineMoveNode.h"
#import "FEngineMoveNode+Private.h"
#import "FEngineInfo.h"
#import "FEngineUtility.h"
#import "ChessGame.hpp"
#import "ChessBoard.hpp"
#import "FFEN.hpp"
#import "Move.hpp"
#import "FPGN.hpp"
#import "ChessEngine.hpp"
#import "ChessOpenings.hpp"

@interface FEngine () {
    ChessEngine engine;
}

// This index is used to keep track of which engine session is currently analyzing.
// It is incremented each time the user cancels the current session and is used to
// avoid firing an update if the engine has been cancelled.
@property (nonatomic, assign) NSUInteger stateIndex;

@end

@implementation FEngine

+ (void)initialize {
    if (self == [FEngine class]) {
        ChessEngine::initialize();
    }
}

- (id)init {
    if (self = [super init]) {
        _async = YES;
        _ttEnabled = NO;
        _searchDepth = INT_MAX;
        _thinkingTime = 5;
        _stateIndex = 0;
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
    return engine.loadOpening(StringFromNSString(pgn));
}

- (BOOL)isValidOpeningMoves {
    std::string name = "";
    return engine.isValidOpeningMoves(name);
}

- (NSString* _Nullable)openingName {
    std::string name = "";
    if (engine.isValidOpeningMoves(name)) {
        return NSStringFromString(name);
    } else {
        return NULL;
    }
}

#pragma mark -

- (BOOL)setFEN:(NSString *)FEN {
    return engine.setFEN(StringFromNSString(FEN));
}

- (NSString*)FEN {
    return NSStringFromString(engine.getFEN());
}

- (BOOL)setPGN:(NSString *)PGN {
    return engine.setPGN(StringFromNSString(PGN));
}

- (NSString*)PGN {
    return NSStringFromString(engine.getPGN());
}

- (NSString*)PGNFormattedForDisplay {
    return NSStringFromString(engine.getPGNForDisplay());
}

- (void)moveNodesFromNode:(ChessGame::MoveNode)node
                 mainLine:(FEngineMoveNode*)mainLine {
    FEngineMoveNode *mainLineNodeWithVariants = nil;
    for (int index=0; index<node.variations.size(); index++) {
        auto child = node.variations[index];
        auto childNode = [[FEngineMoveNode alloc] initWithNode:child];
        if (index == 0) {
            mainLineNodeWithVariants = childNode;
            [mainLine addVariation:childNode];
            [self moveNodesFromNode:child mainLine:mainLine];
        } else {
            [mainLineNodeWithVariants addVariation:childNode];
            [self moveNodesFromNode:child mainLine:childNode];
        }
    }
}

- (NSArray<FEngineMoveNode*>*)moveNodesTree {
    auto root = engine.getRootMoveNode();
    FEngineMoveNode *rootNode = [[FEngineMoveNode alloc] initWithNode:root];
    [self moveNodesFromNode:root mainLine:rootNode];
    return rootNode.variations;
}

- (NSUInteger)currentMoveNodeUUID {
    return engine.game.getCurrentMoveUUID();
}

#pragma mark -

- (NSString*)state {
    return NSStringFromString(engine.getState());
}

- (NSArray<FEngineMove*>* _Nonnull)allMoves {
    NSMutableArray *moves = [NSMutableArray array];
    for (Move move : engine.game.allMoves()) {
        [moves addObject:[self engineMoveFromMove:move]];
    }
    return moves;
}

- (NSArray<FEngineMove*>* _Nonnull)movesAt:(NSUInteger)rank file:(NSUInteger)file {
    NSMutableArray *moves = [NSMutableArray array];
    for (Move move : engine.getMovesAt((File)file, (Rank)rank)) {
        [moves addObject:[self engineMoveFromMove:move]];
    }
    return moves;
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

- (void)move:(NSUInteger)move {
    engine.move((Move)move, "", true);
    [self fireUpdate:self.stateIndex];
}

- (void)move:(NSString*)from to:(NSString*)to {
    engine.move(std::string([from cStringUsingEncoding:NSUTF8StringEncoding]),
                std::string([to cStringUsingEncoding:NSUTF8StringEncoding]));
    [self fireUpdate:self.stateIndex];
}

- (BOOL)canUndoMove {
    return engine.canUndoMove();
}

- (BOOL)canRedoMove {
    return engine.canRedoMove();
}

- (void)undoMove {
    // TODO: handle the cancel with a callback when the cancel actually really happened
    [self cancel];
    engine.undoMove();
    [self fireUpdate:self.stateIndex];
}

- (void)redoMove {
    [self cancel];
    engine.redoMove();
    [self fireUpdate:self.stateIndex];
}

#pragma mark -

- (void)stop {
    engine.stop();
}

- (void)cancel {
    self.stateIndex += 1;
    engine.cancel();
}

- (BOOL)isAnalyzing {
    return engine.running();
}

- (BOOL)isWhite {
    return engine.isWhite();
}

- (BOOL)canPlay {
    return engine.canPlay();
}

- (FEngineInfo*)infoFor:(ChessEvaluation)info {
    FEngineInfo *ei = [[FEngineInfo alloc] init];
    ei.info = info;
    ei.game = engine.game;
    return ei;
}

- (void)analyze:(FEngineSearchCallback _Nonnull)callback {
    [self evaluate:INT_MAX time:0 callback:callback];
}

- (void)evaluate:(FEngineSearchCallback _Nonnull)callback {
    [self evaluate:self.searchDepth time:self.thinkingTime callback:callback];
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
            [self searchBestMove:depth callback:^(FEngineInfo * _Nonnull info, BOOL completed) {
                callback(info, completed);
                [self fireUpdate:localStateIndex];
            }];
        });
    } else {
        [self searchBestMove:depth callback:^(FEngineInfo * _Nonnull info, BOOL completed) {
            callback(info, completed);
            [self fireUpdate:localStateIndex];
        }];
    }
}

- (FEngineInfo*)lookupOpeningMove {
    ChessEvaluation evaluation;
    if (engine.lookupOpeningMove(evaluation)) {
        return [self infoFor:evaluation];
    } else {
        return nil;
    }
}

- (void)searchBestMove:(NSInteger)maxDepth callback:(FEngineSearchCallback)callback {
    // TODO ??
    ChessEvaluater::positionalAnalysis = self.positionalAnalysis;
    engine.transpositionTable = self.ttEnabled;
    
    engine.searchBestMove((int)maxDepth, [self, callback](ChessEvaluation evaluation, bool done) {
        callback([self infoFor:evaluation], done);
    });
}

@end
