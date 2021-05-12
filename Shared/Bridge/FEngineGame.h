//
//  FEngineGame.h
//  BChess
//
//  Created by Jean Bovet on 5/11/21.
//  Copyright © 2021 Jean Bovet. All rights reserved.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface FEngineGame: NSObject
    
@property (nonatomic, assign, readonly) NSUInteger index;
@property (nonatomic, strong, readonly) NSString * _Nonnull name;

@end

NS_ASSUME_NONNULL_END
