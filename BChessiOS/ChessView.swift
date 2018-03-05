//
//  ChessView.swift
//  BChessiOS
//
//  Created by Jean Bovet on 3/2/18.
//  Copyright © 2018 Jean Bovet. All rights reserved.
//

import UIKit

class ChessView: UIView {
    
    var state: ChessViewState? = nil {
        didSet {
            stateChanged()
        }
    }
    
    func stateChanged() {
        guard let state = state else {
            return
        }

        state.pieces.forEach { (name, view) in
            addSubview(view)
        }
        
        setNeedsDisplay()
    }
    
    override func draw(_ rect: CGRect) {
        super.draw(rect)
        
        guard let context = UIGraphicsGetCurrentContext() else {
            return
        }
        
        drawSquares(context: context)
        drawPossibleMoves(context: context)
        drawLastMove(context: context)
    }
    
    func drawSquares(context: CGContext) {
        guard let state = state else {
            return
        }

        var black = false
        for rank: UInt in 0...7 {
            for file: UInt in 0...7 {
                if black {
                    context.setFillColor(UIColor.gray.cgColor)
                } else {
                    context.setFillColor(UIColor(red: 0.9, green: 0.9, blue: 0.9, alpha: 1).cgColor)
                }
                state.layouter.layout(file: file, rank: rank, callback: { rect in
                    context.fill(rect)
                })
                black = !black
            }
            black = !black
        }
    }
    
    func drawPossibleMoves(context: CGContext) {
        guard let state = state, let moves = state.possibleMoves else {
            return
        }

        for move in moves {
            context.setFillColor(UIColor.yellow.withAlphaComponent(0.4).cgColor)
            state.layouter.layout(file: move.fromFile, rank: move.fromRank, callback: { rect in
                context.fill(rect)
            })
            state.layouter.layout(file: move.toFile, rank: move.toRank, callback: { rect in
                context.fill(rect)
            })
        }
    }
    
    func drawLastMove(context: CGContext) {
        guard let state = state else {
            return
        }

        guard let move = state.lastMove else {
            return
        }

        context.setStrokeColor(UIColor.orange.cgColor)
        state.layouter.layout(file: move.fromFile, rank: move.fromRank, callback: { rect in
            context.setLineWidth(1.5)
            context.stroke(rect)
        })
        state.layouter.layout(file: move.toFile, rank: move.toRank, callback: { rect in
            context.setLineWidth(3.0)
            context.stroke(rect)
        })
    }
}

