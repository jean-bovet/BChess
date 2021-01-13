//
//  FEngineInfo.m
//  BChess
//
//  Created by Jean Bovet on 12/3/17.
//  Copyright © 2017 Jean Bovet. All rights reserved.
//

#import "FEngineInfo+Private.h"
#import "FEngineUtility.h"
#import "FEngineMove.h"
#import "Move.hpp"
#import "FPGN.hpp"
#import "ChessEvaluater.hpp"

@implementation FEngineInfo

@synthesize info;

- (NSInteger)depth {
    return self.info.depth;
}

- (NSInteger)time {
    return self.info.time;
}

- (NSInteger)quiescenceDepth {
    return self.info.quiescenceDepth;
}

- (NSInteger)nodeEvaluated {
    return self.info.nodes;
}

- (NSInteger)movesPerSecond {
    return self.info.movesPerSecond;
}

- (NSInteger)value {
    return self.info.value;
}

- (BOOL)isWhite {
    return self.info.engineColor == WHITE;
}

- (BOOL)mat {
    return self.value == ChessEvaluater::MAT_VALUE || self.value == -ChessEvaluater::MAT_VALUE;
}

- (NSUInteger)fromRank {
    return RankFrom(MOVE_FROM((Move)self.bestMove));
}

- (NSUInteger)fromFile {
    return FileFrom(MOVE_FROM((Move)self.bestMove));
}

- (NSUInteger)toRank {
    return RankFrom(MOVE_TO((Move)self.bestMove));
}

- (NSUInteger)toFile {
    return FileFrom(MOVE_TO((Move)self.bestMove));
}

- (NSUInteger)bestMove {
    return self.info.line.bestMove();
}

- (NSString*)opening {
    auto name = self.info.opening;
    if (name.size() > 0) {
        return NSStringFromString(name);
    } else {
        return nil;
    }
}

- (FEngineMove*)bestEngineMove {
    FEngineMove *move = [[FEngineMove alloc] init];
    move.fromFile = self.fromFile;
    move.fromRank = self.fromRank;
    move.toFile = self.toFile;
    move.toRank = self.toRank;
    move.rawMoveValue = self.bestMove;
    return move;
}

- (NSString*)bestMove:(BOOL)uci {
    FPGN::SANType type = uci ? FPGN::SANType::uci : FPGN::SANType::full;
    return NSStringFromString(FPGN::to_string((Move)self.bestMove, type));
}

- (NSString*)bestLine:(BOOL)uci {
    if (uci) {
        NSMutableString *line = [NSMutableString string];
        for (int index=0; index<self.info.line.count; index++) {
            Move move = self.info.line[index];
            if (line.length > 0) {
                [line appendString:@" "];
            }
            [line appendString:NSStringFromString(FPGN::to_string(move, FPGN::SANType::uci))];
        }
        return line;
    } else {
        // Remember the number of moves in the game
        // so we only display the PGN for the best line.
        int cursor = (int)self.game.moveCursor;
        
        // Copy the current game and play the best line.
        ChessGame lineGame = self.game;
        lineGame.history = NEW_HISTORY; // TODO hack to avoid coping the history from self.game and got it overwritten here
        for (int index=0; index<self.info.line.count; index++) {
            Move move = self.info.line[index];
            lineGame.move(move);
        }

        // Get the PGN representation of the best line only
        auto cppString = FPGN::getGame(lineGame, FPGN::Formatting::line, cursor);
        return NSStringFromString(cppString);
    }
}

@end
