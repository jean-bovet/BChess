//
//  Performance.swift
//  BChess
//
//  Created by Jean Bovet on 11/26/17.
//  Copyright © 2017 Jean Bovet. All rights reserved.
//

import Foundation

class Performance {

    var timeElapsed = 0.0
    var movesPerSecond = 0
    var moves = 0
    
    func generate(depth: Int) {
        let before = DispatchTime.now()
        
        moves = _generate(depth: depth)
        
        let after = DispatchTime.now()
        
        let diff = after.uptimeNanoseconds - before.uptimeNanoseconds
        let movesPerSingleNanosecond = Double(moves) / Double(diff)
        
        movesPerSecond = Int(movesPerSingleNanosecond * 1e9)
        timeElapsed = Double(diff) / Double(1e9) // seconds
    }
    
    func _generate(depth: Int) -> Int {
        return 0
    }
    
}

class PerformanceCpp: Performance {
    
    override func _generate(depth: Int) -> Int {
        let engine = FEngine()
        engine.generatePositions(Int32(depth));
        return Int(engine.moveCount);
    }
    
}

