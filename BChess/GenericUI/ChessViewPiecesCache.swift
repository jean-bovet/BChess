//
//  ChessViewPiecesCache.swift
//  BChessiOS
//
//  Created by Jean Bovet on 3/4/18.
//  Copyright © 2018 Jean Bovet. All rights reserved.
//

import Foundation

class ChessViewPiecesCache {
    
    let factory = ChessViewFactory()
    let layouter = ChessViewLayouter()
    
    var cachedPieces = [String:ChessViewPiece]()
    
    func update(boardState: String) -> [ChessViewPiece] {
        let pieces = factory.pieceViews(forState: boardState)
        
        var piecesToRemove = Set<String>(cachedPieces.keys)
        for piece in pieces {
            piecesToRemove.remove(piece.name)
            if let cachedPiece = cachedPieces[piece.name] {
                layouter.layout(file: piece.file, rank: piece.rank, callback: { rect in
                    cachedPiece.view.animator().frame = rect
                    cachedPiece.view.alpha = 1
                })
            } else {
                cachedPieces[piece.name] = piece
                layouter.layout(file: piece.file, rank: piece.rank, callback: { rect in
                    piece.view.animator().frame = rect
                })
            }
        }
        
        // Remove all views that have not been processed
        for pieceName in piecesToRemove {
            cachedPieces[pieceName]?.view.alpha = 0
        }
        
        return cachedPieces.map { $1 }
    }
}
