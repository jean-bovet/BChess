//
//  FBoardEngine.m
//  BChess
//
//  Created by Jean Bovet on 11/27/17.
//  Copyright © 2017 Jean Bovet. All rights reserved.
//

#import "FEngine.h"
#import "FEngineInfo+Private.h"
#import "ChessGame.hpp"
#import "ChessBoard.hpp"
#import "FFEN.hpp"
#import "FMove.hpp"
#import "FPGN.hpp"
#import "ChessEngine.hpp"
#import "IterativeDeepening.hpp"

@implementation FEngineMove

- (BOOL)isPromotion {
    return MOVE_PROMOTION_PIECE((Move)self.rawMoveValue) > 0;
}

- (void)setPromotionPiece:(NSString*)piece {
    Piece promotionPiece = QUEEN;
    if ([[piece lowercaseString] isEqualToString:@"q"]) {
        promotionPiece = QUEEN;
    }
    if ([[piece lowercaseString] isEqualToString:@"r"]) {
        promotionPiece = ROOK;
    }
    if ([[piece lowercaseString] isEqualToString:@"b"]) {
        promotionPiece = BISHOP;
    }
    if ([[piece lowercaseString] isEqualToString:@"n"]) {
        promotionPiece = KNIGHT;
    }
    Move m = (Move)_rawMoveValue;
    SET_MOVE_PROMOTION_PIECE(m, promotionPiece);
    _rawMoveValue = m;
}

@end

@interface FEngine () {
    IterativeDeepening<ChessBoard, ChessMoveGenerator, ChessMoveList, ChessEvaluater> iterativeSearch;
    ChessGame currentGame;
}

@end

@implementation FEngine

- (id)init {
    if (self = [super init]) {
        _async = YES;
        _level = Medium;
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

- (BOOL)setFEN:(NSString *)FEN {
    return currentGame.setFEN(std::string([FEN UTF8String]));
}

- (NSString*)FEN {
    auto fen = currentGame.getFEN();
    return [NSString stringWithUTF8String:fen.c_str()];
}

- (BOOL)setPGN:(NSString *)PGN {
    return FPGN::setGame(std::string([PGN UTF8String]), currentGame);
}

- (NSString*)PGN {
    auto pgn = FPGN::getGame(currentGame);
    return [NSString stringWithUTF8String:pgn.c_str()];
}

- (NSString*)PGNFormattedForDisplay {
    auto pgn = FPGN::getGame(currentGame, FPGN::Formatting::history);
    return [NSString stringWithUTF8String:pgn.c_str()];
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
    [self fireUpdate];
}

- (void)move:(NSString*)from to:(NSString*)to {
    currentGame.move(std::string([from cStringUsingEncoding:NSUTF8StringEncoding]),
                      std::string([to cStringUsingEncoding:NSUTF8StringEncoding]));
    [self fireUpdate];
}

- (BOOL)canUndoMove {
    return currentGame.canUndoMove();
}

- (BOOL)canRedoMove {
    return currentGame.canRedoMove();
}

- (void)undoMove {
    currentGame.undoMove();
    [self fireUpdate];
}

- (void)redoMove {
    currentGame.redoMove();
    [self fireUpdate];
}

- (void)stop {
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

- (NSTimeInterval)timeForLevel:(Level)level {
    switch (level) {
        case Easy:
            return 2;

        case Medium:
            return 5;
            
        case Hard:
            return 20;
    }
}

- (void)analyze:(FEngineSearchCallback _Nonnull)callback {
    [self evaluate:INT_MAX time:0 callback:callback];
}

- (void)evaluate:(FEngineSearchCallback _Nonnull)callback {
    [self evaluate:INT_MAX time:[self timeForLevel:self.level] callback:callback];
}

- (void)evaluate:(NSInteger)depth callback:(FEngineSearchCallback)callback {
    [self evaluate:depth time:0 callback:callback];
}

- (void)evaluate:(NSInteger)depth time:(NSTimeInterval)time callback:(FEngineSearchCallback)callback {
    [self stop];
    
    if (time > 0) {
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(time * NSEC_PER_SEC)), dispatch_get_global_queue(QOS_CLASS_UTILITY, 0), ^{
            [self stop];
        });
    }

    if (self.async) {
        dispatch_async(dispatch_get_global_queue(QOS_CLASS_USER_INITIATED, 0), ^{
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
    ChessBoard board;
    FFEN::setFEN(std::string([boardFEN UTF8String]), board);
    ChessEvaluation info = iterativeSearch.search(board, (int)maxDepth, [self, callback](ChessEvaluation info) {
        callback([self infoFor:info], NO);
    });
    callback([self infoFor:info], YES);
}

- (NSArray<NSString*>* _Nonnull)moveFENsFrom:(NSString* _Nonnull)startingFEN squareName:(NSString* _Nullable)squareName {
    auto fen = std::string([startingFEN UTF8String]);
    ChessBoard board;
    FFEN::setFEN(fen, board);
    std::string boardFEN = FFEN::getFEN(board);
    assert(boardFEN == fen);
    
    Square square;
    if (squareName) {
        square = squareForName(std::string([squareName UTF8String]));
    } else {
        square = SquareUndefined;
    }
    
    ChessMoveGenerator generator;
    ChessMoveList moves = generator.generateMoves(board, ChessMoveGenerator::Mode::allMoves, square);
    NSMutableArray<NSString*>* moveFENs = [NSMutableArray array];
    for (int index=0; index<moves.count; index++) {
        auto move = moves.moves[index];
        ChessBoard newBoard = board;
        newBoard.move(move);
        std::string moveFEN = FFEN::getFEN(newBoard);

        [moveFENs addObject:[NSString stringWithUTF8String:moveFEN.c_str()]];
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
