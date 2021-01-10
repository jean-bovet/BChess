//
//  FUtility.m
//  BChess
//
//  Created by Jean Bovet on 12/30/17.
//  Copyright © 2017 Jean Bovet. All rights reserved.
//

#import "FEngineUtility.h"

NSString * NSStringFromString(std::string cpp) {
    return [NSString stringWithUTF8String:cpp.c_str()];
}

std::string StringFromNSString(NSString * nsString) {
    return std::string([nsString UTF8String]);
}
