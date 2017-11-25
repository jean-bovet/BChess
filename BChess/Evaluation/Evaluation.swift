//
//  MinimaxEvaluation.swift
//  BChess
//
//  Created by Jean Bovet on 11/24/17.
//  Copyright © 2017 Jean Bovet. All rights reserved.
//

import Foundation

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

