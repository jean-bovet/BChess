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
    
    var async = true
    
    typealias Callback = (_ info: FEngineInfo, _ completed: Bool) -> Void
    
    func evaluate(depth: Int, callback: @escaping Callback) {
        internalStopEvaluating()
                
        if async {
            DispatchQueue.global(qos: .userInitiated).async {
                self.internalEvaluate(depth: depth, callback: callback)
            }
        } else {
            internalEvaluate(depth: depth, callback: callback)
        }
    }
    
    func set(fen: String) {
        
    }
    
    func get() -> String {
        return ""
    }
    
    func move(move: Move) {
        internalMove(move: move)
    }
    
    func stop() {
        internalStopEvaluating()
    }

    fileprivate func internalMove(move: Move) {
        
    }

    fileprivate func internalStopEvaluating() {
        
    }
    
    fileprivate func internalEvaluate(depth: Int, callback: @escaping Callback) {
        
    }
    
}

class UCIEngineFast: UCIEngine {
    
    let engine = FEngine()
    
    override func set(fen: String) {
        engine.setFEN(fen)
    }
    
    override func internalMove(move: Move) {
        engine.move(move.description)
    }
    
    override func internalStopEvaluating() {
        engine.stop()
    }
    
    override func internalEvaluate(depth: Int, callback: @escaping Callback) {
        let info = engine.searchBestMove(engine.boardFEN(), maxDepth: UInt(depth)) { info in
            callback(info, false)
        }

        callback(info, true)
    }

}

class UCIEngineClassic: UCIEngine {
 
    var board = Board()
    
    let minimax = Minimax()
    
    override func set(fen: String) {
        board.fen = fen
    }

    override func get() -> String {
        return board.fen
    }
    
    override func internalMove(move: Move) {
        board.move(move: move)
    }
    
    override func internalStopEvaluating() {
        minimax.analyzing = false
    }
    
    override func internalEvaluate(depth: Int, callback: @escaping Callback) {
        let info = self.minimax.searchBestMove(board: self.board, color: self.board.color, maxDepth: depth) { info in
            // info depth 2 score cp 214 time 1242 nodes 2124 nps 34928 pv e2e4 e7e5 g1f3
            // info depth 5 seldepth 29 time 5 nodes 13401 nps 2543 score cp -1 pv b1a3 a7b6 a2a4 a8a4
            callback(info.engineInfo, false)
        }
        
        // bestmove g1f3
        callback(info.engineInfo, true)
    }

}
