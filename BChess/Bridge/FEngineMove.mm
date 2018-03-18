//
//  FEngineMove.m
//  BChess
//
//  Created by Jean Bovet on 12/30/17.
//  Copyright © 2017 Jean Bovet. All rights reserved.
//

#import "FEngineMove.h"
#import "Move.hpp"

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

- (BOOL)isEqual:(id)other {
    if (other == self)
        return YES;
       
    return self.rawMoveValue == ((FEngineMove*)other).rawMoveValue;
}

@end


