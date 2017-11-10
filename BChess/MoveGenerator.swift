//
//  Analysis.swift
//  BChess
//
//  Created by Jean Bovet on 11/9/17.
//  Copyright © 2017 Jean Bovet. All rights reserved.
//

import Foundation

class MoveGenerator {
    
    func generateMoves(board: Board, color: Color) -> [Board] {
        var boards = [Board]()
        for rank in 0...7 {
            for file in 0...7 {
                let piece = board[rank, file]
                if piece.color == color {
                    boards.append(contentsOf: generateMoves(board: board, color: color, cursor: Cursor(rank: rank, file: file)))
                }
            }
        }
        return boards
    }
    
    func generateMoves(board: Board, color: Color, cursor: Cursor) -> [Board] {
        var boards = [Board]()
        let cursors = generateMoves(board: board, cursor: cursor, color: color)
        for c in cursors {
            boards.append(board.move(from: cursor, to: c))
        }
        return boards
    }

    func generateMoves(board: Board, cursor: Cursor, color: Color) -> [Cursor] {
        switch board[cursor].type {
//        case .pawn:
//            return generatePawnCursors(board: board, cursor: cursor, color: color)
        case .bishop:
            return generateBishopCursors(board: board, cursor: cursor, color: color)
        case .rook:
            return generateRookCursors(board: board, cursor: cursor, color: color)
        case .queen:
            return generateQueenCursors(board: board, cursor: cursor, color: color)
        case .king:
            return generateKingCursors(board: board, cursor: cursor, color: color)
        default:
            print("Unknown moves")
            return []
        }
    }
    
    func generatePawnCursors(board: Board, cursor: Cursor, color: Color) -> [Cursor] {
        var cursors = [Cursor]()
        if color == .white {
            cursors.append(cursor.offsetBy(rank: 1), board: board, color: color)
            cursors.append(cursor.offsetBy(rank: 2), board: board, color: color)
        } else {
            cursors.append(cursor.offsetBy(rank: -1), board: board, color: color)
            cursors.append(cursor.offsetBy(rank: -2), board: board, color: color)
        }
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

extension Array where Iterator.Element == Cursor {
    
    // Returns true if the square was empty before moving the piece there
    // which indicates the move generation can certainly continue for
    // bishop, rook and queen.
    @discardableResult mutating func append(_ c: Cursor, board: Board, color: Color) -> Bool {
        guard c.isValid else {
            return false
        }
                
        let piece = board[c]
        
        if piece.isEmpty {
            append(c)
            return true
        }
        
        if piece.color == color.inverse() {
            append(c)
            return false
        }
        
        return false
    }

}
