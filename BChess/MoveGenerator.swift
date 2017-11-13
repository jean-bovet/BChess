//
//  Analysis.swift
//  BChess
//
//  Created by Jean Bovet on 11/9/17.
//  Copyright © 2017 Jean Bovet. All rights reserved.
//

import Foundation

class MoveGenerator {
    
    static func generateMoves(board: Board, color: Color) -> [Move] {
        var moves = [Move]()
        for (piece, cursor) in board {
            if !piece.isEmpty && piece.color == color {
                moves.append(contentsOf: generateMoves(board: board, color: color, position: cursor))
            }
        }
        return moves
    }
    
    static func generateMoves(board: Board, color: Color, position: Coordinate) -> [Move] {
        var moves = [Move]()
        let coordinates = generateMoves(board: board, cursor: position, color: color)
        for coordinate in coordinates {
            let move = Move(from: position, to: coordinate)
            // The new position should not have the king in check (of the color that is moving)
            let board = board.move(move: move)
            if board.isCheck(color: color) {
                continue // skip this position because the knight is still in check
            }
            
            moves.append(move)
        }
        return moves
    }

    static func generateMoves(board: Board, cursor: Coordinate, color: Color) -> [Coordinate] {
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
    
    static func generatePawnCursors(board: Board, cursor: Coordinate, color: Color) -> [Coordinate] {
        var cursors = [Coordinate]()
        if color == .white {
            cursors.append(cursor.offsetBy(rank: 1, file: -1), board: board, color: color, canEat: true, onlyEat: true)
            cursors.append(cursor.offsetBy(rank: 1, file: 1), board: board, color: color, canEat: true, onlyEat: true)

            cursors.append(cursor.offsetBy(rank: 1), board: board, color: color, canEat: false, onlyEat: false)
            if cursor.rank == 1 {
                cursors.append(cursor.offsetBy(rank: 2), board: board, color: color, canEat: false, onlyEat: false)
            }
        } else {
            cursors.append(cursor.offsetBy(rank: -1, file: -1), board: board, color: color, canEat: true, onlyEat: true)
            cursors.append(cursor.offsetBy(rank: -1, file: 1), board: board, color: color, canEat: true, onlyEat: true)

            cursors.append(cursor.offsetBy(rank: -1), board: board, color: color, canEat: false, onlyEat: false)
            if cursor.rank == 7 {
                cursors.append(cursor.offsetBy(rank: -2), board: board, color: color, canEat: false, onlyEat: false)
            }
        }
        return cursors
    }

    static func generateKnightCursors(board: Board, cursor: Coordinate, color: Color) -> [Coordinate] {
        var cursors = [Coordinate]()

        for cursor in MoveGenerator.knightCursors(at: cursor) {
            cursors.append(cursor, board: board, color: color)
        }

        return cursors
    }

    static func knightCursors(at cursor: Coordinate) -> [Coordinate] {
        var cursors = [Coordinate]()
        
        // Top
        cursors.append(cursor.offsetBy(rank: 2, file: -1))
        cursors.append(cursor.offsetBy(rank: 2, file: 1))
        
        // Right
        cursors.append(cursor.offsetBy(rank: 1, file: 2))
        cursors.append(cursor.offsetBy(rank: -1, file: 2))
        
        // Bottom
        cursors.append(cursor.offsetBy(rank: -2, file: 1))
        cursors.append(cursor.offsetBy(rank: -2, file: -1))
        
        // Left
        cursors.append(cursor.offsetBy(rank: -1, file: -2))
        cursors.append(cursor.offsetBy(rank: 1, file: -2))
        
        return cursors
    }
    
    typealias DirectionsType = [(Int, Int)]
    
    static var bishopDirections: DirectionsType {
        return [ (-1, -1), (1, -1),
                 (-1, 1), (1, 1) ]
    }

    static var rookDirections: DirectionsType {
        return [ (-1, 0), (0, 1),
                 (1, 0), (0, -1) ]
    }

    static var queenDirections: DirectionsType {
        return bishopDirections + rookDirections
    }
    
    static func generateBishopCursors(board: Board, cursor: Coordinate, color: Color) -> [Coordinate] {
        return generateCursors(forDirections: bishopDirections, board: board, cursor: cursor, color: color)
    }

    static func generateRookCursors(board: Board, cursor: Coordinate, color: Color) -> [Coordinate] {
        return generateCursors(forDirections: rookDirections, board: board, cursor: cursor, color: color)
    }
    
    static func generateQueenCursors(board: Board, cursor: Coordinate, color: Color) -> [Coordinate] {
        return generateCursors(forDirections: queenDirections, board: board, cursor: cursor, color: color)
    }

    static func generateKingCursors(board: Board, cursor: Coordinate, color: Color) -> [Coordinate] {
        return generateCursors(forDirections: queenDirections, board: board, cursor: cursor, color: color, length: 1)
    }

    static func generateCursors(forDirections directions: DirectionsType, board: Board, cursor: Coordinate, color: Color, length: Int = Board.size) -> [Coordinate] {
        var cursors = [Coordinate]()
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

extension Array where Iterator.Element == Coordinate {
    
    // Returns true if the square was empty before moving the piece there
    // which indicates the move generation can certainly continue for
    // bishop, rook and queen.
    @discardableResult mutating func append(_ c: Coordinate, board: Board, color: Color, canEat: Bool = true, onlyEat: Bool = false) -> Bool {
        guard c.isValid else {
            return false
        }
                
        let piece = board[c]
        
        if piece.isEmpty {
            if onlyEat {
                return false
            } else {
                append(c)
                return true
            }
        }
        
        if piece.color == color.opposite && (canEat || onlyEat) {
            append(c)
            return false
        }
        
        return false
    }

}
