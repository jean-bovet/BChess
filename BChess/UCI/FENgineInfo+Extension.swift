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
        let lineInfo = bestLine.map { $0 }.joined(separator: " ")
        return "info depth \(depth) time \(time) nodes \(nodeEvaluated) nps \(movesPerSecond) score cp \(value) pv \(lineInfo)"
    }
    
    var uciBestMove: String {
        if bestLine.isEmpty {
            return "bestmove ??"
        } else {
            return "bestmove \(bestLine[0])"
        }
    }
}

