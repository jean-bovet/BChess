//
//  UCIEngine.swift
//  BChess
//
//  Created by Jean Bovet on 11/23/17.
//  Copyright © 2017 Jean Bovet. All rights reserved.
//

import Foundation

class UCIEngine {
    
    static let defaultDepth = 6
    
    let engine = FEngine()

    var async = true
    
    typealias Callback = (_ info: FEngineInfo, _ completed: Bool) -> Void
    
    func evaluate(depth: Int, callback: @escaping Callback) {
        stop()
                
        if async {
            DispatchQueue.global(qos: .userInitiated).async {
                self.synchronousEvaluate(depth: depth, callback: callback)
            }
        } else {
            synchronousEvaluate(depth: depth, callback: callback)
        }
    }
    
    func set(fen: String) {
        engine.setFEN(fen)
    }
    
    func get() -> String {
        return engine.boardFEN();
    }
    
    func move(from: String, to: String) {
        engine.move(from, to: to)
    }
    
    func stop() {
        engine.stop()
    }
    
    fileprivate func synchronousEvaluate(depth: Int, callback: @escaping Callback) {
        let info = engine.searchBestMove(engine.boardFEN(), maxDepth: depth) { info in
            callback(info, false)
        }
        
        callback(info, true)
    }
    
}

