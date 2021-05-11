//
//  FEngineMoveNode.h
//  BChess
//
//  Created by Jean Bovet on 5/10/21.
//  Copyright © 2021 Jean Bovet. All rights reserved.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface FEngineMoveNode: NSObject
@property (nonatomic, readonly) NSUInteger moveNumber;
@property (nonatomic, readonly) BOOL whiteMove;
@property (nonatomic, strong, readonly) NSString * _Nonnull name;
@property (nonatomic, strong, readonly) NSString * _Nonnull comment;
@property (nonatomic, strong, readonly) NSArray<FEngineMoveNode*> * _Nonnull variations;
@end

NS_ASSUME_NONNULL_END
