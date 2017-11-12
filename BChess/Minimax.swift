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
    var moveCount: Int
    
    var description: String {
        return "\(move)[\(value)]"
    }
}

class Minimax {
    
    func bestMove(board: Board, color: Color) -> Evaluation {
        return evaluate(board: board, color: color, depth: 1, evaluater: .Maximize)
    }
    
    func evaluate(board: Board, color: Color, depth: Int, evaluater: Evaluater) -> Evaluation {
        let generator = MoveGenerator()
        let moves = generator.generateMoves(board: board, color: color)
        var moveCount = moves.count
        var bestEvaluation = Evaluation(move: Move.invalid(), value: evaluater.startValue, line: [], moveCount: 0)
        for move in moves {
            let board = board.move(move: move)
            if depth < 4 {
                // We haven't reached the final depth yet, so continue to evaluate each position
                let evaluation = evaluate(board: board, color: color.opposite, depth: depth+1, evaluater: evaluater.inverse)
                moveCount += evaluation.moveCount
                if evaluater.isBestValue(current: bestEvaluation.value, new: evaluation.value) {
                    let bestLine = [move] + evaluation.line
                    bestEvaluation = Evaluation(move: move, value: evaluation.value, line: bestLine, moveCount: 0)
                }
            } else {
                // We reached the leaf nodes, let's evaluate each of them to determine the best one
                // Note: always analyze the position relative to white side
                let boardValue = evaluatePosition(board: board, color: .white)
                if evaluater.isBestValue(current: bestEvaluation.value, new: boardValue) {
                    let bestLine = [move]
                    bestEvaluation = Evaluation(move: move, value: boardValue, line: bestLine, moveCount: 0)
                }
            }
        }
        bestEvaluation.moveCount = moveCount
        return bestEvaluation
    }
    
    func evaluatePosition(board: Board, color: Color) -> Int {
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
