//
//  ChessView.swift
//  BChessiOS
//
//  Created by Jean Bovet on 3/2/18.
//  Copyright © 2018 Jean Bovet. All rights reserved.
//

import UIKit

class ChessView: UIView {
    
    let viewState = ChessViewState()
    
    var state: String = "" {
        didSet {
            layout()
        }
    }
    
    var possibleMoves = [FEngineMove]() {
        didSet {
            setNeedsDisplay()
        }
    }

    var lastMove: FEngineMove? = nil {
        didSet {
            setNeedsDisplay()
        }
    }

    func layout() {
        viewState.layouter.viewSize = bounds.size
        viewState.update(state: state, parent: self)
    }
    
    func coordinate(location: CGPoint) -> (UInt, UInt)? {
        return viewState.layouter.coordinate(location: location)
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
        var black = false
        for rank: UInt in 0...7 {
            for file: UInt in 0...7 {
                if black {
                    context.setFillColor(UIColor.gray.cgColor)
                } else {
                    context.setFillColor(UIColor(red: 0.9, green: 0.9, blue: 0.9, alpha: 1).cgColor)
                }
                viewState.layouter.layout(file: file, rank: rank, callback: { rect in
                    context.fill(rect)
                })
                black = !black
            }
            black = !black
        }
    }
    
    func drawPossibleMoves(context: CGContext) {
        for move in possibleMoves {
            context.setFillColor(UIColor.yellow.withAlphaComponent(0.4).cgColor)
            viewState.layouter.layout(file: move.fromFile, rank: move.fromRank, callback: { rect in
                context.fill(rect)
            })
            viewState.layouter.layout(file: move.toFile, rank: move.toRank, callback: { rect in
                context.fill(rect)
            })
        }
    }
    
    func drawLastMove(context: CGContext) {
        guard let move = lastMove else {
            return
        }

        context.setStrokeColor(UIColor.orange.cgColor)
        viewState.layouter.layout(file: move.fromFile, rank: move.fromRank, callback: { rect in
            context.setLineWidth(1.5)
            context.stroke(rect)
        })
        viewState.layouter.layout(file: move.toFile, rank: move.toRank, callback: { rect in
            context.setLineWidth(3.0)
            context.stroke(rect)
        })
    }
}

class ChessViewLayouter {
    
    var viewSize: CGSize = CGSize(width: 0, height: 0) {
        didSet {
            update()
        }
    }
    
    var squareSize: CGFloat = 0
    var squareHorizontalOffset: CGFloat = 0
    var squareVerticalOffset: CGFloat = 0

    func update() {
        let width = round(viewSize.width/8)
        let height = round(viewSize.height/8)
        
        squareSize = min(width, height)
        
        squareHorizontalOffset = round((viewSize.width - CGFloat(8*squareSize))/2)
        squareVerticalOffset = round((viewSize.height - CGFloat(8*squareSize))/2)
    }
    
    func coordinate(location: CGPoint) -> (UInt, UInt)? {
        var value: (UInt, UInt)? = nil
        for rank: UInt in 0...7 {
            for file: UInt in 0...7 {
                layout(file: file, rank: rank, callback: { (rect) in
                    if rect.contains(location) {
                        value = (file, rank)
                    }
                })
            }
        }
        return value
    }
    
    func layout(file: UInt, rank: UInt, callback: (CGRect) -> Void) {
        let rect = CGRect(x: squareHorizontalOffset + CGFloat(file) * squareSize, y: squareVerticalOffset + CGFloat(7 - rank) * squareSize, width: squareSize, height: squareSize)
        callback(rect)
    }
    
}

class ChessViewFactory {
    
    let pieceImageNames = [
        "p" : "pawn_b",
        "P" : "pawn_w",
        "n" : "knight_b",
        "N" : "knight_w",
        "b" : "bishop_b",
        "B" : "bishop_w",
        "r" : "rook_b",
        "R" : "rook_w",
        "q" : "queen_b",
        "Q" : "queen_w",
        "k" : "king_b",
        "K" : "king_w",
        ]
    
    func image(forPiece piece: String) -> UIImage? {
        if let imageName = pieceImageNames[piece] {
            return UIImage(named: imageName)
        } else {
            return nil
        }
    }

    func create(name: String) -> UIView {
        let image = self.image(forPiece: name)!
        let imageView = UIImageView(image: image)
        return imageView
    }
}

class ChessViewState {
    
    var pieces = [String:UIView]()
    
    let factory = ChessViewFactory()
    let layouter = ChessViewLayouter()
    
    func update(state: String, parent: UIView) {
        var cursor = state.startIndex
        var removedPieces = Set<String>(pieces.keys)
        while cursor < state.endIndex {
            let nextCursor = state.index(cursor, offsetBy: 4)
            let token = state[cursor..<nextCursor]
            removedPieces.remove(update(token: String(token), parent: parent))
            cursor = nextCursor
        }
        
        // Remove all views that have not been processed
        for pieceName in removedPieces {
            // TODO: view not removed, should we do that in a cleanup sequence?
            pieces[pieceName]?.alpha = 0
        }
    }
    
    func update(token: String, parent: UIView) -> String {
        let pieceName = String(token.prefix(2))
        let pieceFile = UInt(String(token[token.index(token.startIndex, offsetBy: 2)]))!
        let pieceRank = UInt(String(token[token.index(token.startIndex, offsetBy: 3)]))!
        
        let pieceView = self.pieceView(forName: pieceName, parent: parent)
        layouter.layout(file: pieceFile, rank: pieceRank) { rect in
            pieceView.frame = rect
        }
        
        return pieceName
    }

    func pieceView(forName name: String, parent: UIView) -> UIView {
        if let view = pieces[name] {
            return view
        }
        
        let view = factory.create(name: String(name.prefix(1)))
        parent.addSubview(view)
        pieces[name] = view
        return view
    }
}
