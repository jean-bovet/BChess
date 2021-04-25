//
//  FEngineMove.h
//  BChess
//
//  Created by Jean Bovet on 12/30/17.
//  Copyright © 2017 Jean Bovet. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface FEngineMove: NSObject

@property (nonatomic, assign) NSUInteger fromFile, toFile;
@property (nonatomic, assign) NSUInteger fromRank, toRank;
@property (nonatomic, assign) NSUInteger rawMoveValue;
@property (nonatomic, assign, readonly) BOOL isPromotion;
@property (nonatomic, assign, readonly) BOOL isWhite;
@property (nonatomic, assign, readonly) BOOL isBlack;
@property (nonatomic, assign, readonly) BOOL isCapture;
@property (nonatomic, assign, readonly) NSString* _Nullable capturedPiece;

- (void)setPromotionPiece:(NSString* _Nonnull)piece;

@end

