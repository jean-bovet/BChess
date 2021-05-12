//
//  FEngineMoveNode+Private.c
//  BChess
//
//  Created by Jean Bovet on 5/10/21.
//  Copyright © 2021 Jean Bovet. All rights reserved.
//

#import <Foundation/Foundation.h>
#include "ChessGame.hpp"

NS_ASSUME_NONNULL_BEGIN

@interface FEngineMoveNode ()

@property (nonatomic, readwrite) NSUInteger moveNumber;
@property (nonatomic, readwrite) BOOL whiteMove;
@property (nonatomic, readwrite) NSUInteger uuid;
@property (nonatomic, strong, readwrite) NSString * _Nonnull name;
@property (nonatomic, strong, readwrite) NSString * _Nonnull comment;
@property (nonatomic, strong, readwrite) NSMutableArray<FEngineMoveNode*> * _Nonnull variations;

- (instancetype)initWithNode:(ChessGame::MoveNode)node;

- (void)addVariation:(FEngineMoveNode*)node;

@end

NS_ASSUME_NONNULL_END
