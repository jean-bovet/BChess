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
        var evaluation = Evaluation(move: Move.invalid(), value: 0, line: [])
        for maxDepth in 2...7 {
            evaluateCount = 0
            evaluation = evaluate(board: board,
                                  color: color,
                                  depth: 1,
                                  maxDepth: maxDepth,
                                  evaluater: .Maximize,
                                  move: Move.invalid(),
                                  line: evaluation.line,
                                  alpha: Int.min,
                                  beta: Int.max)
            print("Best move is \(evaluation.move) with \(evaluation.line) and \(evaluateCount) moves evaluated.")
        }
        return evaluation
    }

    // Minim algorithm with alpha-beta pruning
    // http://www.geeksforgeeks.org/minimax-algorithm-in-game-theory-set-1-introduction/
    // http://www.geeksforgeeks.org/minimax-algorithm-in-game-theory-set-4-alpha-beta-pruning/
    func evaluate(board: Board, color: Color, depth: Int, maxDepth: Int, evaluater: Evaluater, move: Move, line: [Move], alpha _alpha: Int, beta _beta: Int) -> Evaluation {
        if depth == maxDepth {
            let boardValue = evaluatePosition(board: board, color: .white)
            return Evaluation(move: move, value: boardValue, line: [])
        }
        
        var moves = generateMoves(board: board, color: color, line: line, depth: depth)
        var bestEvaluation = Evaluation(move: Move.invalid(), value: evaluater.startValue, line: [])
        var alpha = _alpha
        var beta = _beta
        
        if depth - 1 < line.count {
            let lineMove = line[depth - 1]
            evaluate(board, lineMove, color, depth, maxDepth, evaluater, line, &alpha, &beta, &bestEvaluation)
            moves = moves.filter({ $0 != lineMove })
            if beta <= alpha {
                return bestEvaluation
            }
        }

        for move in moves {
            evaluate(board, move, color, depth, maxDepth, evaluater, [], &alpha, &beta, &bestEvaluation)
            
            if beta <= alpha {
                break
            }
        }
        return bestEvaluation
    }
    
    func generateMoves(board: Board, color: Color, line: [Move], depth: Int) -> [Move] {
        let generator = MoveGenerator()
        let moves = generator.generateMoves(board: board, color: color)
            
        if depth - 1 < line.count {
            let lineMove = line[depth - 1]
            return [lineMove] + moves.filter({ $0 != lineMove })
        } else {
            return moves
        }
    }
    
    func evaluate(_ board: Board, _ move: Move, _ color: Color, _ depth: Int, _ maxDepth: Int, _ evaluater: Evaluater, _ line: [Move], _ alpha: inout Int, _ beta: inout Int, _ bestEvaluation: inout Evaluation) {
        let board = board.move(move: move)
        let evaluation = evaluate(board: board,
                                  color: color.opposite,
                                  depth: depth+1,
                                  maxDepth: maxDepth,
                                  evaluater: evaluater.inverse,
                                  move: move,
                                  line: line,
                                  alpha: alpha,
                                  beta: beta)
        if evaluater.isBestValue(current: bestEvaluation.value, new: evaluation.value) {
            let bestLine = [move] + evaluation.line
            bestEvaluation = Evaluation(move: move, value: evaluation.value, line: bestLine)
        }
        
        if evaluater == .Maximize {
            alpha = max(alpha, bestEvaluation.value)
        } else {
            beta = min(beta, bestEvaluation.value)
        }
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
