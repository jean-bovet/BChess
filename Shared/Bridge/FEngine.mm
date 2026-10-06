//
//  FBoardEngine.m
//  BChess
//
//  Created by Jean Bovet on 11/27/17.
//  Copyright © 2017 Jean Bovet. All rights reserved.
//

#import "FEngine.h"
#import "FEngine+Testing.h"
#import "FEngineInfo+Private.h"
#import "FEngineMove.h"
#import "FEngineGame+Private.h"
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

#include <memory>
#include <mutex>

#include <TargetConditionals.h>

// The transposition table's size. It is allocated by the first search, so an engine that never searches
// (the probes that validate a pasted text or a file) costs nothing. A phone has far less memory to give.
static size_t HashMegabytes(bool phone) {
    return phone ? 16 : 64;
}
static const size_t FEngineHashMegabytes = HashMegabytes(TARGET_OS_IPHONE);

// An Objective-C++ instance variable is default-constructed, so the size goes in through a subclass
struct FEngineCore: ChessEngine {
    FEngineCore() : ChessEngine(FEngineHashMegabytes) {}
};

// Threading model.
// - Every search runs on `_searchQueue`, a serial queue, on its own snapshot of the game. Searches on
//   one engine never overlap, so `engine.iterativeSearch` is only touched there.
// - `_generation` identifies the current search request. Every position change, cancel and new
//   request bumps it under `_control`. The search thread re-checks it, and invokes the callback,
//   while holding `_control`. So once cancel, evaluate or a position change has returned, no
//   callback of an earlier search is running or will start. The caller waits at most for one
//   in-flight callback, never for a search.
// - Callbacks never touch the main queue: the UCI tool's main thread sits in readLine.
@interface FEngine () {
    FEngineCore engine;
    dispatch_queue_t _searchQueue;
    std::recursive_mutex _control;
    uint64_t _generation;
    // The generation for which stop was requested, 0 for none. It survives until the search is armed.
    uint64_t _stopRequestedGeneration;
}

@end

@implementation FEngine

@synthesize games;
@synthesize currentGameIndex;
@synthesize currentMoveNodeUUID;

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
        _generation = 0;
        _stopRequestedGeneration = 0;
        _searchQueue = dispatch_queue_create("ch.arizona-software.BChess.search",
                                             dispatch_queue_attr_make_with_qos_class(DISPATCH_QUEUE_SERIAL, QOS_CLASS_USER_INITIATED, 0));
    }
    return self;
}

// Cancels the running search and makes any pending or running search of an earlier generation
// ineffective. Returns the new generation.
- (uint64_t)invalidate {
    std::lock_guard<std::recursive_mutex> lock(_control);
    _generation++;
    engine.cancel();
    return _generation;
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
    [self invalidate];
    return engine.setFEN(StringFromNSString(FEN));
}

- (NSString*)FEN {
    return NSStringFromString(engine.getFEN());
}

- (NSArray<FEngineGame*>*)games {
    NSMutableArray *engineGames = [NSMutableArray array];
    auto games = engine.games;
    for (int index=0; index<games.size(); index++) {
        auto game = games[index];
        FEngineGame *engineGame = [[FEngineGame alloc] initWithGame:game andIndex:index];
        [engineGames addObject:engineGame];
    }
    return engineGames;
}

- (void)setCurrentGameIndex:(NSUInteger)index {
    [self invalidate];
    engine.gameIndex = (unsigned int)index;
}

- (NSUInteger)currentGameIndex {
    return engine.gameIndex;
}

- (BOOL)loadAllGames:(NSString* _Nonnull)PGN {
    [self invalidate];
    return engine.loadAllGames(StringFromNSString(PGN));
}

- (BOOL)setPGN:(NSString *)PGN {
    [self invalidate];
    return engine.setPGN(StringFromNSString(PGN));
}

- (NSString*)getPGN:(BOOL)currentGame {
    return NSStringFromString(engine.getPGN(currentGame));
}

- (NSString* _Nonnull)pgnAllGames {
    return [self getPGN:false];
}

- (NSString* _Nonnull)getPGNCurrentGame {
    return [self getPGN:true];
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

- (void)setCurrentMoveNodeUUID:(NSUInteger)currentMoveNodeUUID {
    [self invalidate];
    engine.game().setCurrentMoveUUID((unsigned int)currentMoveNodeUUID);
}

- (NSUInteger)currentMoveNodeUUID {
    return engine.game().getCurrentMoveUUID();
}

#pragma mark -

- (NSString*)state {
    return NSStringFromString(engine.getState());
}

- (NSArray<FEngineMove*>* _Nonnull)allMoves {
    NSMutableArray *moves = [NSMutableArray array];
    for (Move move : engine.game().allMoves()) {
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
    [self invalidate];
    engine.move((Move)move, "", true);
}

- (BOOL)moveUCI:(NSString*)move {
    [self invalidate];
    return engine.move(StringFromNSString(move));
}

- (ChessGame::Direction)gameDirection:(Direction)direction {
    switch (direction) {
        case start:
            return ChessGame::Direction::start;
        case end:
            return ChessGame::Direction::end;
        case backward:
            return ChessGame::Direction::backward;
        case forward:
            return ChessGame::Direction::forward;
    }
}
- (BOOL)canMoveTo:(Direction)direction {
    return engine.game().canMoveTo([self gameDirection:direction]);
}

- (void)moveTo:(Direction)direction variation:(NSUInteger)variation {
    [self invalidate];
    engine.game().moveTo([self gameDirection:direction], (unsigned int)variation);
}

- (NSArray<FEngineMoveNode*>*)nextMoveChoices {
    NSMutableArray *choices = [NSMutableArray array];
    for (auto & node : engine.game().getNextMoveNodes()) {
        [choices addObject:[[FEngineMoveNode alloc] initWithNode:node]];
    }
    return choices;
}

- (NSUInteger)nextVariation {
    return (NSUInteger)engine.game().getNextVariationIndex();
}

#pragma mark -

- (void)stop {
    std::lock_guard<std::recursive_mutex> lock(_control);
    // Remember the intent for this generation: the search may not be armed yet.
    _stopRequestedGeneration = _generation;
    engine.stop();
}

- (void)cancel {
    [self invalidate];
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

- (GameEnd)gameEnd {
    switch (engine.gameEnd()) {
        case ChessEngine::GameEnd::none: return GameEndNone;
        case ChessEngine::GameEnd::checkmate: return GameEndCheckmate;
        case ChessEngine::GameEnd::stalemate: return GameEndStalemate;
        case ChessEngine::GameEnd::repetition: return GameEndRepetition;
        case ChessEngine::GameEnd::finished: return GameEndFinished;
    }
}

- (FEngineInfo*)infoFor:(ChessEvaluation)info game:(const ChessGame &)game {
    FEngineInfo *ei = [[FEngineInfo alloc] init];
    ei.info = info;
    // Never share the history vector that the search mutates
    ChessGame copy = game;
    copy.history = NEW_HISTORY;
    ei.game = copy;
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
    uint64_t gen = [self invalidate];
    
    if (self.useOpeningBook) {
        FEngineInfo *info = [self lookupOpeningMove];
        if (info) {
            callback(info, YES);
            return;
        }
    }
    
    // The search works on its own copy of the position: the history is modified during the search
    // while the caller keeps moving, undoing or pasting on the real game.
    ChessGame copy = engine.game();
    copy.history = std::make_shared<std::vector<BoardHash>>(*engine.game().history);
    auto snapshot = std::make_shared<const ChessGame>(copy);
    BOOL tt = self.ttEnabled;
    
    dispatch_block_t search = ^{
        {
            std::lock_guard<std::recursive_mutex> lock(self->_control);
            if (gen != self->_generation) {
                // Cancelled or superseded before it started
                return;
            }
            self->engine.iterativeSearch.start();
            if (self->_stopRequestedGeneration == gen) {
                // Honored here: depth 1 still finishes, so the result is a real move
                self->engine.stop();
            }
        }
        
        if (time > 0) {
            // Armed here, so it measures the search time, not the time spent in the queue
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(time * NSEC_PER_SEC)), dispatch_get_global_queue(QOS_CLASS_UTILITY, 0), ^{
                std::lock_guard<std::recursive_mutex> lock(self->_control);
                if (gen == self->_generation) {
                    self->engine.stop();
                }
            });
        }
        
        self->engine.searchBestMove(snapshot->board, snapshot->history, (int)depth, tt, [self, snapshot, gen, callback](ChessEvaluation evaluation, bool done) {
            FEngineInfo *info = [self infoFor:evaluation game:*snapshot];
            std::lock_guard<std::recursive_mutex> lock(self->_control);
            if (gen == self->_generation) {
                callback(info, done);
            }
        });
    };
    
    if (self.async) {
        dispatch_async(_searchQueue, search);
    } else {
        // The inline path is serialized with any search that is still unwinding
        dispatch_sync(_searchQueue, search);
    }
}

- (FEngineInfo*)lookupOpeningMove {
    ChessEvaluation evaluation;
    if (engine.lookupOpeningMove(evaluation)) {
        return [self infoFor:evaluation game:engine.game()];
    } else {
        return nil;
    }
}


// Test hooks, declared in FEngine+Testing.h

- (void)performOnSearchQueue:(dispatch_block_t)block {
    dispatch_async(_searchQueue, block);
}

+ (NSUInteger)hashMegabytesForPhone:(BOOL)phone {
    return HashMegabytes(phone);
}

- (NSUInteger)transpositionTableBytes {
    __block NSUInteger bytes = 0;
    dispatch_sync(_searchQueue, ^{
        bytes = self->engine.iterativeSearch.table.allocatedBytes();
    });
    return bytes;
}

- (void)setSearchCheckpoint:(nullable dispatch_block_t)block {
#ifdef BCHESS_TEST_HOOKS
    if (block) {
        engine.iterativeSearch.minMaxSearch.checkpoint = [block]() { block(); };
    } else {
        engine.iterativeSearch.minMaxSearch.checkpoint = nullptr;
    }
#endif
}

@end
