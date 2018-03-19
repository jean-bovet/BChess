//
//  ChessViewPieces.swift
//  BChessiOS
//
//  Created by Jean Bovet on 3/4/18.
//  Copyright © 2018 Jean Bovet. All rights reserved.
//

import Foundation

class ChessViewPieces {
    
    let factory: ChessViewFactory
    let layouter: ChessViewLayouter
    
    var cache = [String:ChessViewPiece]()
    
    init(factory: ChessViewFactory, layouter: ChessViewLayouter) {
        self.factory = factory
        self.layouter = layouter
    }
    
    func update(boardState: String, animated: Bool = true) -> [ChessViewPiece] {
        let pieces = factory.pieceViews(forState: boardState)
        
        var piecesToRemove = Set<String>(cache.keys)
        for piece in pieces {
            piecesToRemove.remove(piece.name)
            if let cachedPiece = cache[piece.name] {
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
                cache[piece.name] = piece
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
            cache[pieceName]?.view.alpha = 0
        }
        
        return cache.map { $1 }
    }
}
