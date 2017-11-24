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

extension Move: Equatable {
    static func == (lhs: Move, rhs: Move) -> Bool {
        return lhs.from == rhs.from && lhs.to == rhs.to
    }
}

extension Move {
    
    func equals(_ from: Coordinate, _ to: Coordinate) -> Bool {
        return self.from == from && self.to == to
    }
}

extension Move: CustomStringConvertible {
    
    var description: String {
        return "\(from)\(to)"
    }
}
