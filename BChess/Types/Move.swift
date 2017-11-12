//
//  Move.swift
//  BChess
//
//  Created by Jean Bovet on 11/10/17.
//  Copyright © 2017 Jean Bovet. All rights reserved.
//

import Foundation

struct Move {
    let from: Coordinate
    let to: Coordinate
    
    static func invalid() -> Move {
        return Move(from: Coordinate.invalid(), to: Coordinate.invalid())
    }
}

extension Move: CustomStringConvertible {
    
    var description: String {
        return "\(from)\(to)"
    }
}
