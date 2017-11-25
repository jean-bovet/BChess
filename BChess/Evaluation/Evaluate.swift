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
        let generator = MoveGenerator(board: board, color: board.color)
        let moves = generator.generateMoves()
        return evaluate(board: board, moves: moves)
    }
    
    static func evaluate(board: Board, moves: [Move]) -> Int {
        // Check for mate or draw if there are no moves for this position
        if moves.isEmpty {
            if board.isCheck(color: board.color) {
                return board.color == .white ? -90000 : 90000
            } else {
                // TODO Good value to return?
                return 0
            }
        }
        
        // Note: the value should always be computed from a white point of view
        var value = 0
        for (piece, _) in board {
            if piece.isEmpty {
                continue
            }
            
            if piece.color == .white {
                value += piece.type.value * 100
            } else {
                value -= piece.type.value * 100
            }
        }
        
        // Evaluate the number of pieces being attacked
        let attackingBonus = 10
        let checkingBonus = 100
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
