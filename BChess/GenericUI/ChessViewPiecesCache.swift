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
    
    func update(boardState: String, animated: Bool = true) -> [ChessViewPiece] {
        let pieces = factory.pieceViews(forState: boardState)
        
        var piecesToRemove = Set<String>(cachedPieces.keys)
        for piece in pieces {
            piecesToRemove.remove(piece.name)
            if let cachedPiece = cachedPieces[piece.name] {
                if cachedPiece.view.alpha == 0 {
                    layouter.layout(file: piece.file, rank: piece.rank, callback: { rect in
                        cachedPiece.view.frame = rect
                    })
                    cachedPiece.view.animate(animated: animated, callback: { view in
                        view.alpha = 1
                    })
                } else {
                    layouter.layout(file: piece.file, rank: piece.rank, callback: { rect in
                        cachedPiece.view.animate(animated: animated, callback: { view in
                            view.frame = rect
                        })
                    })
                }
            } else {
                cachedPieces[piece.name] = piece
                piece.view.alpha = 0
                layouter.layout(file: piece.file, rank: piece.rank, callback: { rect in
                    piece.view.frame = rect
                })
                piece.view.animate(animated: animated, callback: { view in
                    view.alpha = 1
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
