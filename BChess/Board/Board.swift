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

    var cells = [Piece](repeating: Piece.None, count: size*size)
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
    
    func newBoard(withMove move: Move) -> Board {
        var newBoard = self
        newBoard.move(move: move)
        return newBoard
    }
    
    mutating func move(move: Move) {
        if color == .black {
            fullMoveCount += 1
        }

        color = color.opposite
        
        applyMove(move.from, move.to)
        
        if move.equals(.E1, .G1) {
            // White castle king side, need to move the rook
            applyMove(.H1, .F1)
        }
        if move.equals(.E1, .C1) {
            // White castle queen side, need to move the rook
            applyMove(.A1, .D1)
        }
        if move.equals(.E8, .G8) {
            // White castle king side, need to move the rook
            applyMove(.H8, .F8)
        }
        if move.equals(.E8, .C8) {
            // White castle queen side, need to move the rook
            applyMove(.A8, .D8)
        }

        evaluateCastling(move: move)
    }

    private mutating func applyMove(_ from: Coordinate, _ to: Coordinate) {
        self[to] = self[from]
        self[from] = .None
    }
    
    func position(ofPiece piece: Piece) -> Coordinate? {
        for (p, coordinate) in self {
            if p == piece {
                return coordinate
            }
        }
        return nil
    }
    
    func isCheck(color: Color) -> Bool {
        guard let kingPosition = position(ofPiece: Piece(type: .king, color: color)) else {
            return false
        }

        // Check if king is attacked by the other king
        if isAttackedBy(position: kingPosition, color: color, offsets: MoveGenerator.KingOffsets, type: .king) {
            return true
        }

        // Check if king is attacked by pawns
        if color == .white {
            // Note: we are looking at the black pawns from the point of the view
            // of the king being attacked. We need to use the white pawns attack offsets for that!
            if isAttackedBy(position: kingPosition, color: color, offsets: MoveGenerator.WhitePawnAttackOffsets, type: .pawn) {
                return true
            }
        } else {
            // Note: we are looking at the white pawns from the point of the view
            // of the king being attacked. We need to use the black pawns attack offsets for that!
            if isAttackedBy(position: kingPosition, color: color, offsets: MoveGenerator.BlackPawnAttackOffsets, type: .pawn) {
                return true
            }
        }
        
        // Check if a knight can reach the king
        if isAttackedBy(position: kingPosition, color: color, offsets: MoveGenerator.KnightOffsets, type: .knight) {
            return true
        }
        
        // Check if a bishop or queen can reach the king
        if isAttackedBy(position: kingPosition, color: color, offsets: MoveGenerator.BishopOffsets, types: [.bishop, .queen]) {
            return true
        }

        // Check if a rook or queen can reach the king
        if isAttackedBy(position: kingPosition, color: color, offsets: MoveGenerator.RookOffsets, types: [.rook, .queen]) {
            return true
        }

        return false
    }
    
    func isAttackedBy(position: Coordinate, color: Color, offsets: [(Int, Int)], type: PieceType) -> Bool {
        for (rank, file) in offsets {
            let position = position.newCoordinateByOffset(rank: rank, file: file)
            guard position.isValid else {
                continue
            }
            
            let piece = self[position]
            if piece.type == type && piece.color != color {
                return true
            }
        }
        return false
    }
    
    func isAttackedBy(position: Coordinate, color: Color, offsets: [[(Int, Int)]], types: Set<PieceType>) -> Bool {
        for directionOffsets in offsets {
            for (rank, file) in directionOffsets {
                let position = position.newCoordinateByOffset(rank: rank, file: file)
                guard position.isValid else {
                    // no need to continue on that direction anymore if we are out of the board
                    break
                }
                
                let piece = self[position]
                if piece.isEmpty {
                    continue
                }
                
                if piece.color == color {
                    // no need to continue on that direction if we are hitting a piece from the same color
                    break
                } else {
                    // Check if the piece is a bishop or queen in which case it is check
                    if types.contains(piece.type) {
                        return true
                    } else {
                        // If the piece is something else, then we can stop in that direction
                        // because there is no attack
                        break
                    }
                }
            }
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


