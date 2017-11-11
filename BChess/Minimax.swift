//
//  Minimax.swift
//  BChess
//
//  Created by Jean Bovet on 11/10/17.
//  Copyright © 2017 Jean Bovet. All rights reserved.
//

import Foundation

struct Move {
    let from: Cursor
    let to: Cursor
}

extension Move: CustomStringConvertible {
    
    var description: String {
        return "\(from)\(to)"
    }
}

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

struct EvaluatedMove: CustomStringConvertible {
    let move: Move?
    let value: Int
    
    var description: String {
        if let move = move {
            return "\(move)[\(value)]"
        } else {
            return "?"
        }
    }
}

class Minimax {
    
    func bestMove(board: Board, color: Color) -> EvaluatedMove {
        return evaluate(board: board, color: color, depth: 1, evaluater: .Maximize)
    }
    
    func evaluate(board: Board, color: Color, depth: Int, evaluater: Evaluater) -> EvaluatedMove {
        let generator = MoveGenerator()
        let moves = generator.generateMoves(board: board, color: color)
        var bestMove = EvaluatedMove(move: nil, value: evaluater.startValue)
        for move in moves {
            let board = board.move(from: move.from, to: move.to)
            if depth < 3 {
                // We haven't reached the final depth yet, so continue to evaluate each position
                let evaluation = evaluate(board: board, color: color.inverse(), depth: depth+1, evaluater: evaluater.inverse)
                if evaluater.isBestValue(current: bestMove.value, new: evaluation.value) {
                    bestMove = EvaluatedMove(move: move, value: evaluation.value)
                }
            } else {
                // We reached the leaf nodes, let's evaluate each of them to determine the best one
                let boardValue = evaluatePosition(board: board, color: color)
                if evaluater.isBestValue(current: bestMove.value, new: boardValue) {
                    bestMove = EvaluatedMove(move: move, value: boardValue)
                }
            }
        }
        return bestMove
    }
    
    func evaluatePosition(board: Board, color: Color) -> Int {
        var piecesValue = 0
        for (piece, _) in board {
            if piece.isEmpty {
                continue
            }
            
            if piece.color == color {
                piecesValue += piece.value
            } else {
                piecesValue -= piece.value
            }
        }
        return piecesValue
    }

}
