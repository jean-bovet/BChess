//
//  ChessView.swift
//  BChessiOS
//
//  Created by Jean Bovet on 3/2/18.
//  Copyright © 2018 Jean Bovet. All rights reserved.
//

import CoreGraphics

class ChessView: View {
    
    let piecesCache = ChessViewPiecesCache()

    var layouter: ChessViewLayouter {
        return piecesCache.layouter
    }
    
    var state: ChessViewState? = nil {
        didSet {
            stateChanged()
        }
    }
    
    func stateChanged() {
        guard let state = state else {
            return
        }

        piecesCache.layouter.viewSize = bounds.size
        
        if let boardState = state.boardState {
            let pieces = piecesCache.update(boardState: boardState)
            pieces.forEach { addSubview($0.view) }
        }
        
        setNeedsDisplay()
    }
    
    override func draw(_ rect: CGRect) {
        super.draw(rect)
        
        guard let context = context else {
            return
        }
        
        drawSquares(context: context)
        drawPossibleMoves(context: context)
        drawLastMove(context: context)
    }
    
    func drawSquares(context: CGContext) {
        var black = false
        for rank: UInt in 0...7 {
            for file: UInt in 0...7 {
                if black {
                    context.setFillColor(Color.gray.cgColor)
                } else {
                    context.setFillColor(Color(red: 0.9, green: 0.9, blue: 0.9, alpha: 1).cgColor)
                }
                layouter.layout(file: file, rank: rank, callback: { rect in
                    context.fill(rect)
                })
                black = !black
            }
            black = !black
        }
    }
    
    func drawPossibleMoves(context: CGContext) {
        guard let moves = state?.possibleMoves else {
            return
        }

        for move in moves {
            context.setFillColor(Color.yellow.withAlphaComponent(0.4).cgColor)
            layouter.layout(file: move.fromFile, rank: move.fromRank, callback: { rect in
                context.fill(rect)
            })
            layouter.layout(file: move.toFile, rank: move.toRank, callback: { rect in
                context.fill(rect)
            })
        }
    }
    
    func drawLastMove(context: CGContext) {
        guard let move = state?.lastMove else {
            return
        }

        context.setStrokeColor(Color.orange.cgColor)
        layouter.layout(file: move.fromFile, rank: move.fromRank, callback: { rect in
            context.setLineWidth(1.5)
            context.stroke(rect)
        })
        layouter.layout(file: move.toFile, rank: move.toRank, callback: { rect in
            context.setLineWidth(3.0)
            context.stroke(rect)
        })
    }
}

