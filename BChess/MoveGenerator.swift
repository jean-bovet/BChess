//
//  Analysis.swift
//  BChess
//
//  Created by Jean Bovet on 11/9/17.
//  Copyright © 2017 Jean Bovet. All rights reserved.
//

import Foundation

class MoveGenerator {
    
    let board: Board
    let color: Color
    let verifyCheck: Bool
    
    init(board: Board, color: Color, verifyCheck: Bool = true) {
        self.board = board
        self.color = color
        self.verifyCheck = verifyCheck
    }
    
    func generateMoves() -> [Move] {
        var moves = [Move]()
        for (piece, cursor) in board {
            if !piece.isEmpty && piece.color == color {
                moves.append(contentsOf: generateMoves(position: cursor))
            }
        }
        return moves
    }
    
    func generateMoves(position: Coordinate) -> [Move] {
        switch board[position].type {
        case .pawn:
            return generatePawnMoves(position: position)
        case .bishop:
            return generateBishopMoves(position: position)
        case .rook:
            return generateRookMoves(position: position)
        case .queen:
            return generateQueenMoves(position: position)
        case .king:
            return generateKingMoves(position: position)
        case .knight:
            return generateKnightCursors(position: position)
        case .none:
            return []
        }
    }
    
    // MARK: - Pawn

    func generatePawnMoves(position: Coordinate) -> [Move] {
        var moves = [Move]()
        if color == .white {
            moves.appendMove(generator: self, from: position, to: position.offsetBy(rank: 1, file: -1), canEat: true, mustEat: true)
            moves.appendMove(generator: self, from: position, to: position.offsetBy(rank: 1, file: 1), canEat: true, mustEat: true)

            moves.appendMove(generator: self, from: position, to: position.offsetBy(rank: 1), canEat: false, mustEat: false)
            if position.rank == 1 {
                moves.appendMove(generator: self, from: position, to: position.offsetBy(rank: 2), canEat: false, mustEat: false)
            }
        } else {
            moves.appendMove(generator: self, from: position, to: position.offsetBy(rank: -1, file: -1), canEat: true, mustEat: true)
            moves.appendMove(generator: self, from: position, to: position.offsetBy(rank: -1, file: 1), canEat: true, mustEat: true)

            moves.appendMove(generator: self, from: position, to: position.offsetBy(rank: -1), canEat: false, mustEat: false)
            if position.rank == 7 {
                moves.appendMove(generator: self, from: position, to: position.offsetBy(rank: -2), canEat: false, mustEat: false)
            }
        }
        return moves
    }

    // MARK: - Knight

    func generateKnightCursors(position: Coordinate) -> [Move] {
        var moves = [Move]()

        for cursor in knightCoordinates(at: position) {
            moves.appendMove(generator: self, from: position, to: cursor)
        }

        return moves
    }

    func knightCoordinates(at position: Coordinate) -> [Coordinate] {
        var coordinates = [Coordinate]()
        
        // Top
        coordinates.append(position.offsetBy(rank: 2, file: -1))
        coordinates.append(position.offsetBy(rank: 2, file: 1))
        
        // Right
        coordinates.append(position.offsetBy(rank: 1, file: 2))
        coordinates.append(position.offsetBy(rank: -1, file: 2))
        
        // Bottom
        coordinates.append(position.offsetBy(rank: -2, file: 1))
        coordinates.append(position.offsetBy(rank: -2, file: -1))
        
        // Left
        coordinates.append(position.offsetBy(rank: -1, file: -2))
        coordinates.append(position.offsetBy(rank: 1, file: -2))
        
        return coordinates
    }
    
    typealias DirectionsType = [(Int, Int)]
    
    // MARK: - Bishop
    
    var bishopDirections: DirectionsType {
        return [ (-1, -1), (1, -1),
                 (-1, 1), (1, 1) ]
    }

    func generateBishopMoves(position: Coordinate) -> [Move] {
        return generateMoves(forDirections: bishopDirections, position: position)
    }
    
    // MARK: - Rook

    var rookDirections: DirectionsType {
        return [ (-1, 0), (0, 1),
                 (1, 0), (0, -1) ]
    }

    func generateRookMoves(position: Coordinate) -> [Move] {
        return generateMoves(forDirections: rookDirections, position: position)
    }
    
    // MARK: - Queen

    var queenDirections: DirectionsType {
        return bishopDirections + rookDirections
    }
    
    func generateQueenMoves(position: Coordinate) -> [Move] {
        return generateMoves(forDirections: queenDirections, position: position)
    }

    // MARK: - King

    func generateKingMoves(position: Coordinate) -> [Move] {
        var moves = [Move]()
        moves.append(contentsOf: generateMoves(forDirections: queenDirections, position: position, length: 1))
        moves.append(contentsOf: generateKingCastles(position: position))
        return moves
    }

    func generateKingCastles(position: Coordinate) -> [Move] {
        var moves = [Move]()
        if board.whiteCanCastle && color == .white && position == Coordinate.E1 {
            // King-side: e1 to g1 and Rook h1 to f1
            if board.isEmpty(at: Coordinate.F1) && board.isEmpty(at: Coordinate.G1) {
                moves.appendMove(generator: self, from: Coordinate.E1, to: Coordinate.G1)
                moves.appendMove(generator: self, from: Coordinate.H1, to: Coordinate.F1)
            }
            
            // Queen side
            if board.isEmpty(at: Coordinate.B1) && board.isEmpty(at: Coordinate.C1) && board.isEmpty(at: Coordinate.D1) {
                moves.appendMove(generator: self, from: Coordinate.E1, to: Coordinate.C1)
                moves.appendMove(generator: self, from: Coordinate.A1, to: Coordinate.D1)
            }
        }
        if board.blackCanCastle && color == .black && position == Coordinate.E8 {
            // King-side: e8 to g8 and Rook h8 to f8
            if board.isEmpty(at: Coordinate.F8) && board.isEmpty(at: Coordinate.G8) {
                moves.appendMove(generator: self, from: Coordinate.E8, to: Coordinate.G8)
                moves.appendMove(generator: self, from: Coordinate.H8, to: Coordinate.F8)
            }
            
            // Queen side
            if board.isEmpty(at: Coordinate.B8) && board.isEmpty(at: Coordinate.C8) && board.isEmpty(at: Coordinate.D8) {
                moves.appendMove(generator: self, from: Coordinate.E8, to: Coordinate.C8)
                moves.appendMove(generator: self, from: Coordinate.A8, to: Coordinate.D8)
            }
        }
        return moves
    }
    
    // MARK: - Helpers

    func generateMoves(forDirections directions: DirectionsType, position: Coordinate, length: Int = Board.size) -> [Move] {
        var moves = [Move]()
        for (dx, dy) in directions {
            for distance in 1...length {
                let newPosition = position.offsetBy(rank: dy*distance, file: dx*distance)
                guard moves.appendMove(generator: self, from: position, to: newPosition) else {
                    break
                }
            }
        }
        return moves
    }

}

extension Array where Iterator.Element == Move {
    
    @discardableResult mutating func appendMove(generator: MoveGenerator, from: Coordinate, to: Coordinate, canEat: Bool = true, mustEat: Bool = false) -> Bool {
        guard to.isValid else {
            return false
        }
        
        let piece = generator.board[to]
        
        if piece.isEmpty {
            if !mustEat && isCheckValidated(generator: generator, from: from, to: to) {
                append(Move(from: from, to: to))
            }
            return true
        } else {
            if piece.color == generator.color.opposite && (canEat || mustEat) && isCheckValidated(generator: generator, from: from, to: to) {
                append(Move(from: from, to: to))
            }
            return false
        }
    }
    
    func isCheckValidated(generator: MoveGenerator, from: Coordinate, to: Coordinate) -> Bool {
        guard generator.verifyCheck else {
            return true
        }
        // The new position should not have the king in check (of the color that is moving)
        let newBoard = generator.board.move(move: Move(from: from, to: to))
        if newBoard.isCheck(color: generator.color) {
            return false
        } else {
            return true
        }
    }
}

