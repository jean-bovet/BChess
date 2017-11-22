//
//  Board.swift
//  BChess
//
//  Created by Jean Bovet on 11/9/17.
//  Copyright © 2017 Jean Bovet. All rights reserved.
//

import Foundation

struct Board: CustomStringConvertible {

    static let size = 8

    var cells = [Piece](repeating: Piece.empty(), count: size*size)
    
    subscript(cursor: Coordinate) -> Piece {
        get {
            return cells[cursor.rank*Board.size+cursor.file]
        }
        set {
            cells[cursor.rank*Board.size+cursor.file] = newValue
        }
    }
    
    subscript(rank: Int, file: Int) -> Piece {
        get {
            return cells[rank*Board.size+file]
        }
        set {
            cells[rank*Board.size+file] = newValue
        }
    }
    
    var description: String {
        var text = ""
        for rank in (0...Board.size-1).reversed() {
            for file in 0...Board.size-1 {
                let piece = self[rank, file]
//                text += piece.fenString
                text += piece.unicodeString
            }
            text += "\n"
        }
        return text
    }

}

extension Board: Equatable {
    static func == (lhs: Board, rhs: Board) -> Bool {
        return lhs.cells == rhs.cells
    }
}

extension Board {
    
    func move(move: Move) -> Board {
        var newBoard = Board(cells: Array(cells))
        newBoard[move.to] = newBoard[move.from]
        newBoard[move.from] = Piece.empty()
        return newBoard
    }

    func isCheck(color: Color) -> Bool {
        let generator = MoveGenerator(board: self, color: color.opposite, verifyCheck: false)
        let moves = generator.generateMoves()
        for move in moves {
            let piece = self[move.to]
            guard piece.type == .king && piece.color == color else {
                continue
            }

            return true
        }
        return false
    }
    
    func pawn(at cursor: Coordinate, color: Color) -> Bool {
        return piece(at: cursor, type: .pawn, color: color)
    }
    
    func knight(at cursor: Coordinate, color: Color) -> Bool {
        return piece(at: cursor, type: .knight, color: color)
    }

    func piece(at cursor: Coordinate, type: PieceType, color: Color) -> Bool {
        guard cursor.isValid else {
            return false
        }
        let piece = self[cursor]
        return piece.type == type && piece.color == color
    }

}


