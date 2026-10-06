//
//  FENgineInfo+Extension.swift
//  BChess
//
//  Created by Jean Bovet on 12/9/17.
//  Copyright © 2017 Jean Bovet. All rights reserved.
//

import Foundation

let StartPosFEN = "rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1"

extension FEngineInfo {
    
    var uciInfoMessage: String {
        let lineInfo = bestLine(true)
        
        // For UCI, the value is always from the engine's point of view.
        // Because the evaluation function always evaluate from WHITE's point of view,
        // if the engine is playing black, make sure to inverse the value.
        let uciValue = isWhite ? value : -value
        
        // A mate is counted in moves, not plies, and is negative when the engine is the one mated
        let score: String
        if mat {
            let moves = (matePlies + 1) / 2
            score = "mate \(uciValue > 0 ? moves : -moves)"
        } else {
            score = "cp \(uciValue)"
        }
        
        return "info depth \(depth) seldepth \(selDepth) score \(score) time \(time) nodes \(nodeEvaluated) nps \(movesPerSecond) pv \(lineInfo)"
    }
    
    var uciBestMove: String {
        if hasBestMove, let move = bestMove(true) {
            return "bestmove \(move)"
        } else {
            // The UCI null move: the position has no legal move
            return "bestmove 0000"
        }
    }
}

