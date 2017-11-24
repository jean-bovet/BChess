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
    
    init(board: Board, color: Color) {
        self.board = board
        self.color = color
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

    static let WhitePawnAttackOffsets = [
        (1, -1), (1, 1)
    ]

    static let BlackPawnAttackOffsets = [
        (-1, -1), (-1, 1)
    ]

    func generatePawnMoves(position: Coordinate) -> [Move] {
        var moves = [Move]()
        if color == .white {
            for (rank, file) in MoveGenerator.WhitePawnAttackOffsets {
                moves.appendMove(generator: self, from: position, to: position.newCoordinateByOffset(rank: rank, file: file), canEat: true, mustEat: true)
            }

            moves.appendMove(generator: self, from: position, to: position.newCoordinateByOffset(rank: 1, file: 0), canEat: false, mustEat: false)
            if position.rank == 1 {
                moves.appendMove(generator: self, from: position, to: position.newCoordinateByOffset(rank: 2, file: 0), canEat: false, mustEat: false)
            }
        } else {
            for (rank, file) in MoveGenerator.BlackPawnAttackOffsets {
                moves.appendMove(generator: self, from: position, to: position.newCoordinateByOffset(rank: rank, file: file), canEat: true, mustEat: true)
            }

            moves.appendMove(generator: self, from: position, to: position.newCoordinateByOffset(rank: -1, file: 0), canEat: false, mustEat: false)
            if position.rank == 7 {
                moves.appendMove(generator: self, from: position, to: position.newCoordinateByOffset(rank: -2, file: 0), canEat: false, mustEat: false)
            }
        }
        return moves
    }

    // MARK: - Knight

    static let KnightOffsets = [
        // Top
        (2, -1), (2, 1),
        // Right
        (1, 2), (-1, 2),
        // Bottom
        (-2, 1), (-2, -1),
        // Left
        (-1, -2), (1, -2)
    ]
    
    func generateKnightCursors(position: Coordinate) -> [Move] {
        var moves = [Move]()

        for (deltaRank, deltaFile) in MoveGenerator.KnightOffsets {
            moves.appendMove(generator: self, from: position, to: position.newCoordinateByOffset(rank: deltaRank, file: deltaFile))
        }
        
        return moves
    }
    
    // MARK: - Bishop

    static let BishopOffsets = [
        [ (1, 1), (2, 2), (3, 3), (4, 4), (5, 5), (6, 6), (7, 7), (8, 8)],
        [ (1, -1), (2, -2), (3, -3), (4, -4), (5, -5), (6, -6), (7, -7), (8, -8)],
        [ (-1, -1), (-2, -2), (-3, -3), (-4, -4), (-5, -5), (-6, -6), (-7, -7), (-8, -8)],
        [ (-1, 1), (-2, 2), (-3, 3), (-4, 4), (-5, 5), (-6, 6), (-7, 7), (-8, 8)],
        ]
    
    func generateBishopMoves(position: Coordinate) -> [Move] {
        var moves = [Move]()
        for directionOffsets in MoveGenerator.BishopOffsets {
            for offset in directionOffsets {
                guard moves.appendMove(generator: self, from: position, to: position.newCoordinateByOffset(rank: offset.0, file: offset.1)) else {
                    break
                }
            }
        }
        return moves
    }
    
    // MARK: - Rook

    static let RookOffsets = [
        [ (1, 0), (2, 0), (3, 0), (4, 0), (5, 0), (6, 0), (7, 0), (8, 0)],
        [ (0, 1), (0, 2), (0, 3), (0, 4), (0, 5), (0, 6), (0, 7), (0, 8)],
        [ (0, -1), (0, -2), (0, -3), (0, -4), (0, -5), (0, -6), (0, -7), (0, -8)],
        [ (-1, 0), (-2, 0), (-3, 0), (-4, 0), (-5, 0), (-6, 0), (-7, 0), (-8, 0)],
    ]

    func generateRookMoves(position: Coordinate) -> [Move] {
        var moves = [Move]()
        for directionOffsets in MoveGenerator.RookOffsets {
            for offset in directionOffsets {
                guard moves.appendMove(generator: self, from: position, to: position.newCoordinateByOffset(rank: offset.0, file: offset.1)) else {
                    break
                }
            }
        }
        return moves
    }
    
    // MARK: - Queen

    static let QueenOffsets = MoveGenerator.BishopOffsets + MoveGenerator.RookOffsets
    
    func generateQueenMoves(position: Coordinate) -> [Move] {
        var moves = [Move]()
        for directionOffsets in MoveGenerator.QueenOffsets {
            for offset in directionOffsets {
                guard moves.appendMove(generator: self, from: position, to: position.newCoordinateByOffset(rank: offset.0, file: offset.1)) else {
                    break
                }
            }
        }
        return moves
    }

    // MARK: - King

    static let KingOffsets = [
        (-1, -1), (-1, 0), (-1, 1),
        (1, -1), (1, 0), (1, 1),
        (0, 1), (0, -1)
    ]
    
    func generateKingMoves(position: Coordinate) -> [Move] {
        var moves = [Move]()
        for (deltaRank, deltaFile) in MoveGenerator.KingOffsets {
            moves.appendMove(generator: self, from: position, to: position.newCoordinateByOffset(rank: deltaRank, file: deltaFile))
        }
        moves.append(contentsOf: generateKingCastles(position: position))
        return moves
    }

    func generateKingCastles(position: Coordinate) -> [Move] {
        var moves = [Move]()
        if board.castling.whiteKingSide && color == .white && position == Coordinate.E1 {
            // King-side: e1 to g1 and Rook h1 to f1
            if board.isEmpty(at: Coordinate.F1) && board.isEmpty(at: Coordinate.G1) {
                moves.appendMove(generator: self, from: Coordinate.E1, to: Coordinate.G1)
                moves.appendMove(generator: self, from: Coordinate.H1, to: Coordinate.F1)
            }
        }
        
        if board.castling.whiteQueenSide && color == .white && position == Coordinate.E1 {
            // Queen side
            if board.isEmpty(at: Coordinate.B1) && board.isEmpty(at: Coordinate.C1) && board.isEmpty(at: Coordinate.D1) {
                moves.appendMove(generator: self, from: Coordinate.E1, to: Coordinate.C1)
                moves.appendMove(generator: self, from: Coordinate.A1, to: Coordinate.D1)
            }
        }
        if board.castling.blackKingSide && color == .black && position == Coordinate.E8 {
            // King-side: e8 to g8 and Rook h8 to f8
            if board.isEmpty(at: Coordinate.F8) && board.isEmpty(at: Coordinate.G8) {
                moves.appendMove(generator: self, from: Coordinate.E8, to: Coordinate.G8)
                moves.appendMove(generator: self, from: Coordinate.H8, to: Coordinate.F8)
            }
        }
        
        if board.castling.blackQueenSide && color == .black && position == Coordinate.E8 {
            // Queen side
            if board.isEmpty(at: Coordinate.B8) && board.isEmpty(at: Coordinate.C8) && board.isEmpty(at: Coordinate.D8) {
                moves.appendMove(generator: self, from: Coordinate.E8, to: Coordinate.C8)
                moves.appendMove(generator: self, from: Coordinate.A8, to: Coordinate.D8)
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
        // The new position should not have the king in check (of the color that is moving)
        let newBoard = generator.board.newBoard(withMove: Move(from: from, to: to))
        if newBoard.isCheck(color: generator.color) {
            return false
        } else {
            return true
        }
    }
}

