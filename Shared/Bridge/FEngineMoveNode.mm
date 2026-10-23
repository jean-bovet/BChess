//
//  FEngineMoveNode.m
//  BChess
//
//  Created by Jean Bovet on 5/10/21.
//  Copyright © 2021 Jean Bovet. All rights reserved.
//

#import "FEngineMoveNode.h"
#import "FEngineMoveNode+Private.h"
#import "FEngineUtility.h"

#include "ChessGame.hpp"
#include "FPGN.hpp"

@implementation FEngineMoveNode

- (instancetype)initWithNode:(ChessGame::MoveNode)node {
    return [self initWithNode:node name:FPGN::to_string(node.move, FPGN::SANType::tight)];
}

- (instancetype)initWithNode:(ChessGame::MoveNode)node boardBefore:(ChessBoard)boardBefore {
    return [self initWithNode:node name:FPGN::san(boardBefore, node.move)];
}

- (instancetype)initWithNode:(ChessGame::MoveNode)node name:(const std::string &)name {
    if (self = [super init]) {
        self.moveNumber = node.moveNumber;
        self.whiteMove = MOVE_COLOR(node.move) == WHITE;
        self.fromFile = FileFrom(MOVE_FROM(node.move));
        self.fromRank = RankFrom(MOVE_FROM(node.move));
        self.toFile = FileFrom(MOVE_TO(node.move));
        self.toRank = RankFrom(MOVE_TO(node.move));
        self.uuid = node.uuid;
        self.name = NSStringFromString(name);
        self.comment = NSStringFromString(node.comment);
        self.variations = [NSMutableArray array];
    }
    return self;
}

- (void)addVariation:(FEngineMoveNode*)node {
    [_variations addObject:node];
}

@end
