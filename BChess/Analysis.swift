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

// Minim algorithm with alpha-beta pruning and iterative deepening first search
// http://www.geeksforgeeks.org/minimax-algorithm-in-game-theory-set-1-introduction/
// http://www.geeksforgeeks.org/minimax-algorithm-in-game-theory-set-4-alpha-beta-pruning/
// https://en.wikipedia.org/wiki/Iterative_deepening_depth-first_search
class Analysis {
    
    var evaluateCount = 0
    
    func searchBestMove(board: Board, color: Color) -> Evaluation {
        // minimax(0, 0, true, -INFINITY, +INFINITY)
        var evaluation = Evaluation(move: Move.invalid(), value: 0, line: [])
        for maxDepth in 2...7 {
            evaluateCount = 0
            let before = DispatchTime.now()
            evaluation = evaluate(board: board,
                                  color: color,
                                  depth: 1,
                                  maxDepth: maxDepth,
                                  evaluater: .Maximize,
                                  line: evaluation.line,
                                  alpha: Int.min,
                                  beta: Int.max)
            let after = DispatchTime.now()
            
            let diff = after.uptimeNanoseconds - before.uptimeNanoseconds
            let movesPerSingleNanosecond = Double(evaluateCount) / Double(diff)
            let movesPerSecond = Int(movesPerSingleNanosecond * 1e9)
            print("Best move is \(evaluation.move) with \(evaluation.line) and \(evaluateCount) moves evaluated in \(movesPerSecond) move/sec")
        }
        return evaluation
    }
    
    func evaluate(board: Board,
                  color: Color,
                  depth: Int,
                  maxDepth: Int,
                  evaluater: Evaluater,
                  line: [Move],
                  alpha _alpha: Int,
                  beta _beta: Int) -> Evaluation {
        
        var bestEvaluation = Evaluation(move: Move.invalid(), value: evaluater.startValue, line: [])
        var alpha = _alpha
        var beta = _beta
        
        let moves = MoveGenerator.generateMoves(board: board, color: color)
        var lineMove: Move? = nil
        
        if depth - 1 < line.count {
            lineMove = line[depth - 1]
            if evaluateAlphaBeta(board, lineMove!, color, depth, maxDepth, evaluater, line, &alpha, &beta, &bestEvaluation) {
                return bestEvaluation
            }
        }
        
        for move in moves {
            guard move != lineMove else {
                continue
            }
            
            if evaluateAlphaBeta(board, move, color, depth, maxDepth, evaluater, [], &alpha, &beta, &bestEvaluation) {
                break
            }
        }
        return bestEvaluation
    }
    
    func evaluateAlphaBeta(_ board: Board,
                           _ move: Move,
                           _ color: Color,
                           _ depth: Int,
                           _ maxDepth: Int,
                           _ evaluater: Evaluater,
                           _ line: [Move],
                           _ alpha: inout Int,
                           _ beta: inout Int,
                           _ bestEvaluation: inout Evaluation) -> Bool {

        if depth == maxDepth {
            let boardValue = positionEvaluation(board: board, color: .white)
            bestEvaluation = Evaluation(move: move, value: boardValue, line: [])
            return true
        }

        evaluateCount += 1

        let board = board.move(move: move)
        let evaluation = evaluate(board: board,
                                  color: color.opposite,
                                  depth: depth+1,
                                  maxDepth: maxDepth,
                                  evaluater: evaluater.inverse,
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
        
        // Returns true if the evaluation can stop because the best move has been found
        return beta <= alpha
    }
    
    func positionEvaluation(board: Board, color: Color) -> Int {
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