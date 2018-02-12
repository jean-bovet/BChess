//
//  Types.hpp
//  BChess
//
//  Created by Jean Bovet on 1/6/18.
//  Copyright © 2018 Jean Bovet. All rights reserved.
//

#pragma once

#include <vector>

typedef uint64_t BoardHash;

typedef std::shared_ptr<std::vector<BoardHash>> HistoryPtr;

#define NEW_HISTORY std::make_shared<std::vector<BoardHash>>()
