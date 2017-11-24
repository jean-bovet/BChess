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
    
    var lineInfo: String {
        return line.map { $0.description }.joined(separator: " ")
    }
}

// Minim algorithm with alpha-beta pruning and iterative deepening first search
// http://www.geeksforgeeks.org/minimax-algorithm-in-game-theory-set-1-introduction/
// http://www.geeksforgeeks.org/minimax-algorithm-in-game-theory-set-4-alpha-beta-pruning/
// https://en.wikipedia.org/wiki/Iterative_deepening_depth-first_search
class Analysis {
    
    var evaluateCount = 0
    var analyzing = false
    
    struct Info {
        let depth: Int
        let time: Int
        let evaluation: Evaluation
        let nodeEvaluated: Int
        let movesPerSecond: Int
    }
    
    typealias SearchBestMoveCallback = (Info) -> Void
    
    func searchBestMove(board: Board, color: Color, maxDepth: Int, callback: SearchBestMoveCallback) -> Info {
        analyzing = true
        
        var evaluation = Evaluation(move: Move.invalid(), value: 0, line: [])
        var info = Info(depth: 0, time: 0, evaluation: evaluation, nodeEvaluated: 0, movesPerSecond: 0)
        
        for curMaxDepth in 2...maxDepth {
            guard analyzing else {
                break
            }
            
            evaluateCount = 0
            let before = DispatchTime.now()
            evaluation = evaluate(board: board,
                                  color: color,
                                  depth: 1,
                                  maxDepth: curMaxDepth,
                                  evaluater: (color == .white) ? .Maximize : .Minimize,
                                  line: evaluation.line,
                                  alpha: Int.min,
                                  beta: Int.max)
            let after = DispatchTime.now()
            
            let diff = after.uptimeNanoseconds - before.uptimeNanoseconds
            let movesPerSingleNanosecond = Double(evaluateCount) / Double(diff)
            let movesPerSecond = Int(movesPerSingleNanosecond * 1e9)
            
            info = Info(depth: curMaxDepth,
                        time: Int(Double(diff)/1e9),
                        evaluation: evaluation,
                        nodeEvaluated: evaluateCount,
                        movesPerSecond: movesPerSecond)
            callback(info)
        }
        return info
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
        
        guard analyzing else {
            return bestEvaluation
        }

        var alpha = _alpha
        var beta = _beta
        
        let generator = MoveGenerator(board: board, color: color)
        let moves = generator.generateMoves()
        var lineMove: Move? = nil

        if depth - 1 < line.count {
            lineMove = line[depth - 1]
            if evaluateAlphaBeta(board, lineMove!, color, depth, maxDepth, evaluater, line, &alpha, &beta, &bestEvaluation) {
                return bestEvaluation
            }
        }
        
        for move in moves {
            guard analyzing else {
                break
            }

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
            let boardValue = Evaluate.evaluate(board: board)
            bestEvaluation = Evaluation(move: move, value: boardValue, line: [])
            return true
        }

        evaluateCount += 1

        let evaluation = evaluate(board: board.newBoard(withMove: move),
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
    
}
