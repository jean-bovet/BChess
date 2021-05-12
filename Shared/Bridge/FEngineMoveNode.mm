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
    if (self = [super init]) {
        self.moveNumber = node.moveNumber;
        self.whiteMove = MOVE_COLOR(node.move) == WHITE;
        self.uuid = node.uuid;
        self.name = NSStringFromString(FPGN::to_string(node.move, FPGN::SANType::tight));
        self.comment = NSStringFromString(node.comment);
        self.variations = [NSMutableArray array];
    }
    return self;
}

- (void)addVariation:(FEngineMoveNode*)node {
    [_variations addObject:node];
}

@end
