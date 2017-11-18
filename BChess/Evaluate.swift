//
//  Evaluate.swift
//  BChess
//
//  Created by Jean Bovet on 11/13/17.
//  Copyright © 2017 Jean Bovet. All rights reserved.
//

import Foundation

class Evaluate {
    
    static func evaluate(board: Board, color: Color) -> Int {
        var value = 0
        for (piece, _) in board {
            if piece.isEmpty {
                continue
            }
            
            let myColor = piece.color == color
            
            if myColor {
                value += piece.type.value
            } else {
                value -= piece.type.value
            }
        }
        
        // Evaluate the number of pieces being attacked
        let attackingBonus = 3
        let moves = MoveGenerator.generateMoves(board: board, color: color)
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
            
            if colorIsAttacking {
                value += attackingBonus
            } else {
                value -= attackingBonus
            }
        }
        return value
    }
    
}
