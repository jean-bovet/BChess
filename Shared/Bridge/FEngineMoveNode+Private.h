//
//  FEngineMoveNode+Private.c
//  BChess
//
//  Created by Jean Bovet on 5/10/21.
//  Copyright © 2021 Jean Bovet. All rights reserved.
//

#import <Foundation/Foundation.h>
#include "ChessGame.hpp"
#include "ChessBoard.hpp"

NS_ASSUME_NONNULL_BEGIN

@interface FEngineMoveNode ()

@property (nonatomic, readwrite) NSUInteger moveNumber;
@property (nonatomic, readwrite) BOOL whiteMove;
@property (nonatomic, readwrite) NSUInteger uuid;
@property (nonatomic, readwrite) NSUInteger fromRank;
@property (nonatomic, readwrite) NSUInteger toRank;
@property (nonatomic, readwrite) NSUInteger fromFile;
@property (nonatomic, readwrite) NSUInteger toFile;
@property (nonatomic, strong, readwrite) NSString * _Nonnull name;
@property (nonatomic, strong, readwrite) NSString * _Nonnull comment;
@property (nonatomic, strong, readwrite) NSMutableArray<FEngineMoveNode*> * _Nonnull variations;

// The root node, which carries no move
- (instancetype)initWithNode:(ChessGame::MoveNode)node;

// A move node named in SAN from the board it is played from (checks, mates and disambiguation included)
- (instancetype)initWithNode:(ChessGame::MoveNode)node boardBefore:(ChessBoard)boardBefore;

- (void)addVariation:(FEngineMoveNode*)node;

@end

NS_ASSUME_NONNULL_END
