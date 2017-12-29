//
//  FEngineInfo.h
//  BChess
//
//  Created by Jean Bovet on 12/3/17.
//  Copyright © 2017 Jean Bovet. All rights reserved.
//

#import "FEngineInfo.h"
#import "ChessEvaluation.hpp"
#import "ChessGame.hpp"

@interface FEngineInfo ()

@property (nonatomic, assign) ChessEvaluation info;
@property (nonatomic, assign) ChessGame game;

@end
