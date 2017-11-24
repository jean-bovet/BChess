//
//  Evaluate.swift
//  BChess
//
//  Created by Jean Bovet on 11/13/17.
//  Copyright © 2017 Jean Bovet. All rights reserved.
//

import Foundation

class Evaluate {
    
    static func evaluate(board: Board) -> Int {
        let color = Color.white // always evaluate from a white point of view
        var value = 0
        for (piece, _) in board {
            if piece.isEmpty {
                continue
            }
            
            let myColor = piece.color == color
            
            if myColor {
                value += piece.type.value * 100
            } else {
                value -= piece.type.value * 100
            }
        }
        
        // Evaluate the number of pieces being attacked
        let attackingBonus = 10
        let checkingBonus = 100
        let generator = MoveGenerator(board: board, color: color)
        let moves = generator.generateMoves()
        for move in moves {
            let colorIsAttacking = board[move.from].color == color
            let targetSquare = board[move.to]
            
            // Ignore if the target square is empty
            guard !targetSquare.isEmpty else {
                continue
            }
            
            // Check that the target square is of the opposite color
            // Note: the move generator should already do that
            assert(targetSquare.color != color, "Target square should be of the opposite color")
            
            if targetSquare.type == .king {
                if colorIsAttacking {
                    value += checkingBonus
                } else {
                    value -= checkingBonus
                }
            } else {
                if colorIsAttacking {
                    value += attackingBonus
                } else {
                    value -= attackingBonus
                }
            }
        }
        return value
    }
    
}
