//
//  FColor.hpp
//  BChess
//
//  Created by Jean Bovet on 12/2/17.
//  Copyright © 2017 Jean Bovet. All rights reserved.
//

#pragma once

enum Color: int {
    WHITE, BLACK, COUNT
};

#define INVERSE(color) ((color) == Color::WHITE ? Color::BLACK : Color::WHITE)

