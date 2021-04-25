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

- (BOOL)isWhite {
    return MOVE_COLOR((Move)self.rawMoveValue) == WHITE;
}

- (BOOL)isBlack {
    return MOVE_COLOR((Move)self.rawMoveValue) == BLACK;
}

- (BOOL)isCapture {
    return MOVE_IS_CAPTURE((Move)self.rawMoveValue);
}

- (NSString*)capturedPiece {
    BOOL cw = MOVE_CAPTURED_PIECE_COLOR((Move)self.rawMoveValue) == WHITE;
    Piece p = MOVE_CAPTURED_PIECE((Move)self.rawMoveValue);
    switch (p) {
        case PAWN:
            return cw ? @"P" : @"p";
        case KNIGHT:
            return cw ? @"N" : @"n";
        case BISHOP:
            return cw ? @"B" : @"b";
        case ROOK:
            return cw ? @"R" : @"r";
        case QUEEN:
            return cw ? @"Q" : @"q";
        case KING:
            return cw ? @"K" : @"k";
        case PCOUNT:
            return NULL;
    }
    return NULL;
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


