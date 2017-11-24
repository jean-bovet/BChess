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
    
    var board = Board()

    let minimax = Analysis()
    
    var async = true
    
    typealias Callback = (_ info: Analysis.Info, _ completed: Bool) -> Void

    func evaluate(depth: Int, callback: @escaping Callback) {
        minimax.analyzing = false
        let evaluateBlock = {
            let info = self.minimax.searchBestMove(board: self.board, color: self.board.color, maxDepth: depth) { info in
                // info depth 2 score cp 214 time 1242 nodes 2124 nps 34928 pv e2e4 e7e5 g1f3
                // info depth 5 seldepth 29 time 5 nodes 13401 nps 2543 score cp -1 pv b1a3 a7b6 a2a4 a8a4
                callback(info, false)
            }
            
            // bestmove g1f3
            callback(info, true)
        }
        
        if async {
            DispatchQueue.global(qos: .userInitiated).async(execute: evaluateBlock)
        } else {
            evaluateBlock()
        }
    }
    
}
