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
    
    static let Invalid = Coordinate(rank: Int.max, file: Int.max)

    static let letters = ["a", "b", "c", "d", "e", "f", "g", "h"]
    
    static let A1 = "a1".coordinate!
    static let B1 = "b1".coordinate!
    static let C1 = "c1".coordinate!
    static let D1 = "d1".coordinate!
    static let E1 = "e1".coordinate!
    static let F1 = "f1".coordinate!
    static let G1 = "g1".coordinate!
    static let H1 = "h1".coordinate!

    static let A8 = "a8".coordinate!
    static let B8 = "b8".coordinate!
    static let C8 = "c8".coordinate!
    static let D8 = "d8".coordinate!
    static let E8 = "e8".coordinate!
    static let F8 = "f8".coordinate!
    static let G8 = "g8".coordinate!
    static let H8 = "h8".coordinate!
    
    func newCoordinateByOffset(rank rankValue: Int, file fileValue: Int) -> Coordinate {
        return Coordinate(rank: rank + rankValue, file: file + fileValue)
    }
    
    var isValid: Bool {
        return rank >= 0 && rank < Board.size && file >= 0 && file < Board.size
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


