//
//  Board.swift
//  BChess
//
//  Created by Jean Bovet on 11/9/17.
//  Copyright © 2017 Jean Bovet. All rights reserved.
//

import Foundation

struct Castling {
    var whiteKingSide = true
    var whiteQueenSide = true
    var blackKingSide = true
    var blackQueenSide = true    
}

struct Board: CustomStringConvertible {

    static let size = 8

    var cells = [Piece](repeating: Piece.none(), count: size*size)
    var color = Color.white
    
    var castling = Castling()
    
    // Fullmove number: The number of the full move. It starts at 1, and is incremented after Black's move
    var fullMoveCount = 1
    
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
    
    func evaluateCastling(move: Move) {
        /*
 Your king has been moved earlier in the game.
 The rook that castles has been moved earlier in the game.
 There are pieces standing between your king and rook.
 The king is in check.
 The king moves through a square that is attacked by a piece of the opponent.
 The king would be in check after castling.
*/
    }
}

extension Board {
    
    func move(move: Move) -> Board {
        var newBoard = Board()
        newBoard.color = color.opposite
        newBoard.castling = castling
        newBoard.fullMoveCount = fullMoveCount
        newBoard.cells = Array(cells)
        
        if color == .black {
            newBoard.fullMoveCount += 1
        }

        newBoard.inlineMove(move.from, move.to)
        
        if move.equals(.E1, .G1) {
            // White castle king side, need to move the rook
            newBoard.inlineMove(.H1, .F1)
        }
        if move.equals(.E1, .C1) {
            // White castle queen side, need to move the rook
            newBoard.inlineMove(.A1, .D1)
        }
        if move.equals(.E8, .G8) {
            // White castle king side, need to move the rook
            newBoard.inlineMove(.H8, .F8)
        }
        if move.equals(.E8, .C8) {
            // White castle queen side, need to move the rook
            newBoard.inlineMove(.A8, .D8)
        }

        newBoard.evaluateCastling(move: move)
        return newBoard
    }

    mutating func inlineMove(_ from: Coordinate, _ to: Coordinate) {
        self[to] = self[from]
        self[from] = .none()
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

    func isEmpty(at coordinate: Coordinate) -> Bool {
        return piece(at: coordinate, type: .none, color: .white)
    }
    
    func piece(at cursor: Coordinate, type: PieceType, color: Color) -> Bool {
        guard cursor.isValid else {
            return false
        }
        let piece = self[cursor]
        if type == .none {
            return piece.type == type
        } else {
            return piece.type == type && piece.color == color
        }
    }

}


