//
//  Analysis.swift
//  BChess
//
//  Created by Jean Bovet on 11/9/17.
//  Copyright © 2017 Jean Bovet. All rights reserved.
//

import Foundation

class MoveGenerator {
    
    func generateMoves(board: Board, color: Color) -> [Move] {
        let checked = board.isCheck(color: color)
        var moves = [Move]()
        for (piece, cursor) in board {
            if !piece.isEmpty && piece.color == color {
                moves.append(contentsOf: generateMoves(board: board, color: color, cursor: cursor, checked: checked))
            }
        }
        return moves
    }
    
    func generateMoves(board: Board, color: Color, cursor: Cursor, checked: Bool) -> [Move] {
        var moves = [Move]()
        let cursors = generateMoves(board: board, cursor: cursor, color: color)
        for c in cursors {
            if checked {
                // The new position needs to clear the check otherwise it is invalid
                let board = board.move(from: cursor, to: c)
                if board.isCheck(color: color) {
                   continue // skip this position because the knight is still in check
                }
            }
            moves.append(Move(from: cursor, to: c))
        }
        return moves
    }

    func generateMoves(board: Board, cursor: Cursor, color: Color) -> [Cursor] {
        switch board[cursor].type {
        case .pawn:
            return generatePawnCursors(board: board, cursor: cursor, color: color)
        case .bishop:
            return generateBishopCursors(board: board, cursor: cursor, color: color)
        case .rook:
            return generateRookCursors(board: board, cursor: cursor, color: color)
        case .queen:
            return generateQueenCursors(board: board, cursor: cursor, color: color)
        case .king:
            return generateKingCursors(board: board, cursor: cursor, color: color)
        case .knight:
            return generateKnightCursors(board: board, cursor: cursor, color: color)
        case .none:
            return []
        }
    }
    
    func generatePawnCursors(board: Board, cursor: Cursor, color: Color) -> [Cursor] {
        var cursors = [Cursor]()
        if color == .white {
            cursors.append(cursor.offsetBy(rank: 1, file: -1), board: board, color: color, canEat: true, onlyEat: true)
            cursors.append(cursor.offsetBy(rank: 1, file: 1), board: board, color: color, canEat: true, onlyEat: true)

            cursors.append(cursor.offsetBy(rank: 1), board: board, color: color, canEat: false, onlyEat: false)
            cursors.append(cursor.offsetBy(rank: 2), board: board, color: color, canEat: false, onlyEat: false)
        } else {
            cursors.append(cursor.offsetBy(rank: -1, file: -1), board: board, color: color, canEat: true, onlyEat: true)
            cursors.append(cursor.offsetBy(rank: -1, file: 1), board: board, color: color, canEat: true, onlyEat: true)

            cursors.append(cursor.offsetBy(rank: -1), board: board, color: color, canEat: false, onlyEat: false)
            cursors.append(cursor.offsetBy(rank: -2), board: board, color: color, canEat: false, onlyEat: false)
        }
        return cursors
    }

    func generateKnightCursors(board: Board, cursor: Cursor, color: Color) -> [Cursor] {
        var cursors = [Cursor]()

        for cursor in MoveGenerator.knightCursors(at: cursor) {
            cursors.append(cursor, board: board, color: color)
        }

        return cursors
    }

    static func knightCursors(at cursor: Cursor) -> [Cursor] {
        var cursors = [Cursor]()
        
        // Top
        cursors.append(cursor.offsetBy(rank: 2, file: -1))
        cursors.append(cursor.offsetBy(rank: 2, file: 1))
        
        // Right
        cursors.append(cursor.offsetBy(rank: 1, file: 2))
        cursors.append(cursor.offsetBy(rank: -1, file: 2))
        
        // Bottom
        cursors.append(cursor.offsetBy(rank: -2, file: -1))
        cursors.append(cursor.offsetBy(rank: -2, file: 1))
        
        // Left
        cursors.append(cursor.offsetBy(rank: 1, file: -2))
        cursors.append(cursor.offsetBy(rank: -1, file: -2))
        
        return cursors
    }
    
    typealias DirectionsType = [(Int, Int)]
    
    var bishopDirections: DirectionsType {
        return [ (-1, -1), (1, -1),
                 (-1, 1), (1, 1) ]
    }

    var rookDirections: DirectionsType {
        return [ (-1, 0), (0, 1),
                 (1, 0), (0, -1) ]
    }

    var queenDirections: DirectionsType {
        return bishopDirections + rookDirections
    }
    
    func generateBishopCursors(board: Board, cursor: Cursor, color: Color) -> [Cursor] {
        return generateCursors(forDirections: bishopDirections, board: board, cursor: cursor, color: color)
    }

    func generateRookCursors(board: Board, cursor: Cursor, color: Color) -> [Cursor] {
        return generateCursors(forDirections: rookDirections, board: board, cursor: cursor, color: color)
    }
    
    func generateQueenCursors(board: Board, cursor: Cursor, color: Color) -> [Cursor] {
        return generateCursors(forDirections: queenDirections, board: board, cursor: cursor, color: color)
    }

    func generateKingCursors(board: Board, cursor: Cursor, color: Color) -> [Cursor] {
        return generateCursors(forDirections: queenDirections, board: board, cursor: cursor, color: color, length: 1)
    }

    func generateCursors(forDirections directions: DirectionsType, board: Board, cursor: Cursor, color: Color, length: Int = 7) -> [Cursor] {
        var cursors = [Cursor]()
        for (dx, dy) in directions {
            for distance in 1...length {
                let newCursor = cursor.offsetBy(rank: dy*distance, file: dx*distance)
                guard cursors.append(newCursor, board: board, color: color) else {
                    break
                }
            }
        }
        return cursors
    }

}

enum MoveConstraint {
    case canEat
    case onlyEat
}

extension Array where Iterator.Element == Cursor {
    
    // Returns true if the square was empty before moving the piece there
    // which indicates the move generation can certainly continue for
    // bishop, rook and queen.
    @discardableResult mutating func append(_ c: Cursor, board: Board, color: Color, canEat: Bool = true, onlyEat: Bool = false) -> Bool {
        guard c.isValid else {
            return false
        }
                
        let piece = board[c]
        
        if piece.isEmpty && !onlyEat {
            append(c)
            return true
        }
        
        if piece.color == color.inverse() && (canEat || onlyEat) {
            append(c)
            return false
        }
        
        return false
    }

}
