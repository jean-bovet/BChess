//
//  Position.swift
//  BChess
//
//  Created by Jean Bovet on 1/10/21.
//  Copyright © 2021 Jean Bovet. All rights reserved.
//

import Foundation

struct Position {
    let rank: Int
    let file: Int
    
    static func empty() -> Position {
        return Position(rank: -1, file: -1)
    }
}
    
