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
    
    static let letters = ["a", "b", "c", "d", "e", "f", "g", "h"]

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

extension String {
    var coordinate: Coordinate? {
        guard count == 2 else {
            return nil
        }
        
        let fileIndex = self.index(self.startIndex, offsetBy: 0)
        let rankIndex = self.index(self.startIndex, offsetBy: 1)

        let file = Coordinate.letters.index(of: String(self[fileIndex]))
        let rank = Int(String(self[rankIndex]))
        
        guard let f = file, let r = rank else {
            return nil
        }
        
        return Coordinate(rank: r - 1, file: f)
    }
}

extension Int {
    var letter: String {
        if self >= 0 && self < Coordinate.letters.count {
            return Coordinate.letters[self]
        } else {
            return "?"
        }
    }
}


