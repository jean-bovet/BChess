//
//  Coordinate.swift
//  BChess
//
//  Created by Jean Bovet on 11/10/17.
//  Copyright © 2017 Jean Bovet. All rights reserved.
//

import Foundation

struct Coordinate {
    var rank = 0
    var file = 0
    
    func offsetBy(rank rankValue: Int) -> Coordinate {
        return offsetBy(rank: rankValue, file: 0)
    }
    
    func offsetBy(rank rankValue: Int, file fileValue: Int) -> Coordinate {
        return Coordinate(rank: rank + rankValue, file: file + fileValue)
    }
    
    var isValid: Bool {
        return rank >= 0 && rank < Board.size && file >= 0 && file < Board.size
    }
    
    static func invalid() -> Coordinate {
        return Coordinate(rank: Int.max, file: Int.max)
    }
}

extension Coordinate: Equatable {
    static func == (lhs: Coordinate, rhs: Coordinate) -> Bool {
        return lhs.rank == rhs.rank && lhs.file == rhs.file
    }
}

extension Coordinate: CustomStringConvertible {
    
    var description: String {
        return "\(file.letter)\(rank+1)"
    }
}

extension Int {
    var letter: String {
        let letters = ["a", "b", "c", "d", "e", "f", "g", "h"]
        if self >= 0 && self < letters.count {
            return letters[self]
        } else {
            return "?"
        }
    }
}


