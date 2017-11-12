//
//  Minimax.swift
//  BChess
//
//  Created by Jean Bovet on 11/10/17.
//  Copyright © 2017 Jean Bovet. All rights reserved.
//

import Foundation

enum Evaluater {
    case Minimize
    case Maximize
    
    var inverse: Evaluater {
        switch self {
        case .Maximize:
            return .Minimize
        case .Minimize:
            return .Maximize
        }
    }
    
    var startValue: Int {
        switch self {
        case .Maximize:
            return Int.min
        case .Minimize:
            return Int.max
        }
    }
    
    func isBestValue(current: Int, new: Int) -> Bool {
        switch self {
        case .Maximize:
            return new > current
        case .Minimize:
            return new < current
        }
    }
}

struct Evaluation: CustomStringConvertible {
    let move: Move
    let value: Int
    let line: [Move]
    
    var description: String {
        return "\(move)[\(value)]"
    }
}

class Minimax {
    
    var evaluateCount = 0
    
    func bestMove(board: Board, color: Color) -> Evaluation {
        // minimax(0, 0, true, -INFINITY, +INFINITY)
        return evaluate(board: board, color: color, depth: 1, evaluater: .Maximize, move: Move.invalid(), alpha: Int.min, beta: Int.max)
    }

    // Minim algorithm with alpha-beta pruning
    // http://www.geeksforgeeks.org/minimax-algorithm-in-game-theory-set-1-introduction/
    // http://www.geeksforgeeks.org/minimax-algorithm-in-game-theory-set-4-alpha-beta-pruning/
    func evaluate(board: Board, color: Color, depth: Int, evaluater: Evaluater, move: Move, alpha _alpha: Int, beta _beta: Int) -> Evaluation {
        if depth == 5 {
            let boardValue = evaluatePosition(board: board, color: .white)
            return Evaluation(move: move, value: boardValue, line: [])
        }
        
        let generator = MoveGenerator()
        let moves = generator.generateMoves(board: board, color: color)
        var bestEvaluation = Evaluation(move: Move.invalid(), value: evaluater.startValue, line: [])
        var alpha = _alpha
        var beta = _beta
        for move in moves {
            let board = board.move(move: move)
            let evaluation = evaluate(board: board, color: color.opposite, depth: depth+1, evaluater: evaluater.inverse, move: move, alpha: alpha, beta: beta)
            if evaluater.isBestValue(current: bestEvaluation.value, new: evaluation.value) {
                let bestLine = [move] + evaluation.line
                bestEvaluation = Evaluation(move: move, value: evaluation.value, line: bestLine)
            }
            
            if evaluater == .Maximize {
                alpha = max(alpha, bestEvaluation.value)
            } else {
                beta = min(beta, bestEvaluation.value)
            }
            
            if beta <= alpha {
                break
            }
        }
        return bestEvaluation
    }
    
    func evaluatePosition(board: Board, color: Color) -> Int {
        evaluateCount += 1
        
        var piecesValue = 0
        for (piece, _) in board {
            if piece.isEmpty {
                continue
            }
            
            if piece.color == color {
                piecesValue += piece.type.value
            } else {
                piecesValue -= piece.type.value
            }
        }
        return piecesValue
    }

}
