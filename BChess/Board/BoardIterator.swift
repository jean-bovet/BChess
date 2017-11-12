//
//  BoardIterator.swift
//  BChess
//
//  Created by Jean Bovet on 11/10/17.
//  Copyright © 2017 Jean Bovet. All rights reserved.
//

import Foundation

struct BoardIterator: IteratorProtocol {
    
    let board: Board
    var coordinate: Coordinate
    
    init(board: Board, cursor: Coordinate) {
        self.board = board
        self.coordinate = cursor
    }
    
    mutating func next() -> (Piece, Coordinate)? {
        coordinate.file += 1
        if coordinate.file >= Board.size {
            coordinate.file = 0
            coordinate.rank += 1
            if coordinate.rank >= Board.size {
                return nil
            }
        }
        return (board[coordinate], coordinate)
    }
}

extension Board: Sequence {
    
    func makeIterator() -> BoardIterator {
        return BoardIterator(board: self, cursor: Coordinate(rank: 0, file: 0))
    }
}

