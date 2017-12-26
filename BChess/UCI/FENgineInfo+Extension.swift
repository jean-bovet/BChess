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
        let uciValue: String
        if isWhite {
            uciValue = String(value)
        } else {
            uciValue = String(-value)
        }
        
        let totalDepth = max(depth, quiescenceDepth)
        
        return "info depth \(totalDepth) time \(time) nodes \(nodeEvaluated) nps \(movesPerSecond) score cp \(uciValue) pv \(lineInfo)"
    }
    
    var uciBestMove: String {
        if let move = bestMove(true) {
            return "bestmove \(move)"
        } else {
            return "bestmove ??"
        }
    }
}

