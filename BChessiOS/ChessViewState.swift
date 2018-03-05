//
//  ChessViewState.swift
//  BChessiOS
//
//  Created by Jean Bovet on 3/4/18.
//  Copyright © 2018 Jean Bovet. All rights reserved.
//

import Foundation
import UIKit

class ChessViewState {
        
    var boardState: String? = nil {
        didSet {
            update(state: boardState)
        }
    }

    var possibleMoves: [FEngineMove]? = nil
    
    var lastMove: FEngineMove? = nil

    var pieces = [String:UIView]()
    
    let factory = ChessViewFactory()
    let layouter = ChessViewLayouter()
    
    func update(state: String?) {
        guard let state = state else {
            return
        }
        
        var cursor = state.startIndex
        var removedPieces = Set<String>(pieces.keys)
        while cursor < state.endIndex {
            let nextCursor = state.index(cursor, offsetBy: 4)
            let token = state[cursor..<nextCursor]
            removedPieces.remove(update(token: String(token)))
            cursor = nextCursor
        }
        
        // Make sure all pieces are visible
        pieces.forEach { (name, view) in
            view.alpha = 1
        }
        
        // Remove all views that have not been processed
        for pieceName in removedPieces {
            pieces[pieceName]?.alpha = 0
        }
    }
    
    func update(token: String) -> String {
        let pieceName = String(token.prefix(2))
        let pieceFile = UInt(String(token[token.index(token.startIndex, offsetBy: 2)]))!
        let pieceRank = UInt(String(token[token.index(token.startIndex, offsetBy: 3)]))!
        
        let pieceView = self.pieceView(forName: pieceName)
        layouter.layout(file: pieceFile, rank: pieceRank) { rect in
            pieceView.frame = rect
        }
        
        return pieceName
    }
    
    func pieceView(forName name: String) -> UIView {
        if let view = pieces[name] {
            return view
        }
        
        let view = factory.create(name: String(name.prefix(1)))
        pieces[name] = view
        return view
    }
}
