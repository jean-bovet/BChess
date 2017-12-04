//
//  UCIEngine.swift
//  BChess
//
//  Created by Jean Bovet on 11/23/17.
//  Copyright © 2017 Jean Bovet. All rights reserved.
//

import Foundation

class UCIEngine {
    
    static let defaultDepth = 4
    
    let engine = FEngine()

    var async = true
    
    typealias Callback = (_ info: FEngineInfo, _ completed: Bool) -> Void
    
    func evaluate(depth: Int, callback: @escaping Callback) {
        stop()
                
        if async {
            DispatchQueue.global(qos: .userInitiated).async {
                self.internalEvaluate(depth: depth, callback: callback)
            }
        } else {
            internalEvaluate(depth: depth, callback: callback)
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
    
    fileprivate func internalEvaluate(depth: Int, callback: @escaping Callback) {
        let info = engine.searchBestMove(engine.boardFEN(), maxDepth: UInt(depth)) { info in
            callback(info, false)
        }
        
        callback(info, true)
    }
    
}

