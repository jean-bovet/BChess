//
//  Evaluate.swift
//  BChess
//
//  Created by Jean Bovet on 11/13/17.
//  Copyright © 2017 Jean Bovet. All rights reserved.
//

import Foundation

class Evaluate {
    
    static let scoreMat = 90000
    
    static let scorePieceFactor = 100 // Pawn=100, Queen=900

    // Bonus for each piece that is attacking or being attacked
    static let attackingBonus = 50
    
    // Bonus each time the king is in check
    static let checkingBonus = 100

    static let locationFactor: [Int] = [
        0,  0,  0,  0,  0,  0,  0,  0,
        0,  0,  0,  0,  0,  0,  0,  0,
        0,  0,  2,  2,  2,  2,  0,  0,
        0,  0,  2,  3,  3,  2,  0,  0,
        0,  0,  2,  3,  3,  2,  0,  0,
        0,  0,  2,  2,  2,  2,  0,  0,
        0,  0,  0,  0,  0,  0,  0,  0,
        0,  0,  0,  0,  0,  0,  0,  0,
    ]
    
    static func evaluate(board: Board) -> Int {
        let generator = MoveGenerator(board: board, color: board.color)
        let moves = generator.generateMoves()
        return evaluate(board: board, moves: moves)
    }
    
    static func evaluate(board: Board, moves: [Move]) -> Int {
        // Check for mate or draw if there are no moves for this position
        if moves.isEmpty {
            if board.isCheck(color: board.color) {
                return board.color == .white ? -scoreMat : scoreMat
            } else {
                // TODO Good value to return?
                return 0
            }
        }
        
        // Note: the value should always be computed from a white point of view
        var value = 0
        for (piece, coordinate) in board {
            if piece.isEmpty {
                continue
            }
            
            let locFactor = locationFactor[coordinate.rank*Board.size+coordinate.file]
            let pieceBonus = piece.type.value * locFactor
            if piece.color == .white {
                value += piece.type.value * scorePieceFactor + pieceBonus
            } else {
                value -= piece.type.value * scorePieceFactor + pieceBonus
            }
        }
        
        // Evaluate the number of pieces being attacked
        let whiteIsAttacking = board.color == .white
        for move in moves {
            let targetSquare = board[move.to]
            
            // Ignore if the target square is empty
            guard !targetSquare.isEmpty else {
                continue
            }
            
            // Check that the target square is of the opposite color
            // Note: the move generator should already do that
            assert(targetSquare.color != board.color, "Target square should be of the opposite color")
            
            if targetSquare.type == .king {
                if whiteIsAttacking {
                    value += checkingBonus
                } else {
                    value -= checkingBonus
                }
            } else {
                if whiteIsAttacking {
                    value += attackingBonus
                } else {
                    value -= attackingBonus
                }
            }
        }
        
        return value
    }
    
}
