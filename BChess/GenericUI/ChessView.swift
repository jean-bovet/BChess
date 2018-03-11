//
//  ChessView.swift
//  BChessiOS
//
//  Created by Jean Bovet on 3/2/18.
//  Copyright © 2018 Jean Bovet. All rights reserved.
//

import CoreGraphics
import CoreText

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
        
        drawBorders(context: context)
        drawSquares(context: context)
        drawLabels(context: context)
        drawPossibleMoves(context: context)
        drawLastMove(context: context)
    }
    
    func drawBorders(context: CGContext) {
        context.setStrokeColor(Color.black.cgColor)
        context.setLineWidth(2.0)
        context.stroke(layouter.boardFrame)
    }
    
    func drawSquares(context: CGContext) {
        var black = true
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

    let files = [ "a", "b", "c", "d", "e", "f", "g", "h" ]

    func drawLabels(context: CGContext) {

        for file: UInt in 0...7 {
            layouter.layout(file: file, rank: 0, callback: { rect in
                let white = file % 2 == 0
                drawText(context: context, x: rect.origin.x + rect.size.width - 2, y: rect.origin.y, text: files[Int(file)], white: white, hAlign: .Right)
            })
        }
        
        for rank: UInt in 0...7 {
            layouter.layout(file: 0, rank: rank, callback: { rect in
                let white = rank % 2 == 0
                drawText(context: context, x: rect.origin.x + 2, y: rect.origin.y + rect.size.height, text: String(rank+1), white: white, vAlign: .Top)
            })
        }
    }
    
    enum VAlign {
        case Top
        case Bottom
    }

    enum HAlign {
        case Left
        case Right
    }

    func drawText(context: CGContext, x: CGFloat, y: CGFloat, text: String, white: Bool, vAlign: VAlign = .Bottom, hAlign: HAlign = .Left) {
        context.saveGState()
        
        context.textMatrix = CGAffineTransform.identity;
//        context.scaleBy(x: 1.0, y: -1.0);
        
        let str = NSMutableAttributedString(string: text)
        
        str.addAttribute(NSAttributedStringKey(rawValue: kCTForegroundColorAttributeName as String),
                         value: white ? Color.white : Color.black , range: NSMakeRange(0,str.length))
        
        let fontRef = Font.systemFont(ofSize: 10, weight: Font.Weight.bold)
        let attributes = [NSAttributedStringKey(rawValue: kCTFontAttributeName as String) : fontRef]
        str.addAttribute(NSAttributedStringKey(rawValue: kCTFontAttributeName as String), value: fontRef, range:NSMakeRange(0, str.length))
        
        let frameSetter = CTFramesetterCreateWithAttributedString(str)
        
        let size = CTFramesetterSuggestFrameSizeWithConstraints(frameSetter, CFRangeMake(0, str.length), attributes as CFDictionary, CGSize(width: CGFloat.greatestFiniteMagnitude, height:CGFloat.greatestFiniteMagnitude), nil)

        let path = CGMutablePath()
        path.addRect(CGRect(x: 0, y: 0, width: size.width, height: size.height))

        var hoffset: CGFloat = 0
        switch hAlign {
        case .Left:
            hoffset = 0
        case .Right:
            hoffset = -path.boundingBox.size.width
        }
        
        var voffset: CGFloat = 0
        switch vAlign {
        case .Top:
            voffset = -path.boundingBox.size.height
        case .Bottom:
            voffset = 0
        }

        context.translateBy(x: x + hoffset, y: y + voffset);

        let ctFrame = CTFramesetterCreateFrame(frameSetter, CFRangeMake(0, str.length), path, nil)
        
        CTFrameDraw(ctFrame, context)
        
        context.restoreGState()
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

