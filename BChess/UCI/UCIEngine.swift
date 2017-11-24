//
//  UCIEngine.swift
//  BChess
//
//  Created by Jean Bovet on 11/23/17.
//  Copyright © 2017 Jean Bovet. All rights reserved.
//

import Foundation

protocol UCIEngineDelegate: class {
    func engineOutput(_ message: String)
}

class UCIEngine {
    
    var board = Board()

    let minimax = Analysis()
    
    var async = true
    
    weak var delegate: UCIEngineDelegate?
        
    func evaluate(depth: Int) {
        minimax.analyzing = false
        let evaluateBlock = {
            let info = self.minimax.searchBestMove(board: self.board, color: self.board.color, maxDepth: depth) { info in
                // info depth 2 score cp 214 time 1242 nodes 2124 nps 34928 pv e2e4 e7e5 g1f3
                // info depth 5 seldepth 29 time 5 nodes 13401 nps 2543 score cp -1 pv b1a3 a7b6 a2a4 a8a4
                let message = info.uciInfoMessage
                self.delegate?.engineOutput(message)
            }
            
            // bestmove g1f3
            let message = info.uciBestMove
            self.delegate?.engineOutput(message)
        }
        
        if async {
            DispatchQueue.global(qos: .userInitiated).async(execute: evaluateBlock)
        } else {
            evaluateBlock()
        }
    }
    
}
