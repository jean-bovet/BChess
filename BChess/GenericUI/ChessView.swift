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
    
    let layouter = ChessViewLayouter()
    let factory = ChessViewFactory()
    let piecesCache: ChessViewPieces
    
    var state: ChessViewState? = nil {
        didSet {
            stateChanged()
        }
    }
    
    var labelsInside = false
    
    var rotated = false {
        didSet {
            layouter.rotated = rotated
            stateChanged()
        }
    }
    
    var animated = true
    
    override init(frame frameRect: Rect) {
        piecesCache = ChessView.initCache(factory: factory, layouter: layouter)
        super.init(frame: frameRect)
    }
    
    required init?(coder decoder: NSCoder) {
        piecesCache = ChessView.initCache(factory: factory, layouter: layouter)
        super.init(coder: decoder)
    }
    
    private static func initCache(factory: ChessViewFactory, layouter: ChessViewLayouter) -> ChessViewPieces {
        return ChessViewPieces(factory: factory, layouter: layouter)
    }
    
    #if os(OSX)
    override func resize(withOldSuperviewSize oldSize: NSSize) {
        super.resize(withOldSuperviewSize: oldSize)
        stateChanged(animated: false)
    }
    #else
    override func layoutSubviews() {
        super.layoutSubviews()
        stateChanged()
    }
    #endif
    
    // MARK: - State -

    func stateChanged() {
        stateChanged(animated: animated)
    }
    
    func stateChanged(animated: Bool) {
        guard let state = state else {
            return
        }

        piecesCache.layouter.viewSize = bounds.size
        
        if let boardState = state.boardState {
            let pieces = piecesCache.update(boardState: boardState, animated: animated)
            pieces.forEach { addSubview($0.view) }
        }
        
        setNeedsDisplay()
    }
    
    // MARK: - Drawing -
    
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
        context.setStrokeColor(Color.lightGray.cgColor)
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
                let white: Bool
                let x, y : CGFloat
                let vAlign: VAlign
                let hAlign: HAlign
                if labelsInside {
                    white = file % 2 == 0
                    x = rect.maxX - 2
                    y = rect.origin.y
                    vAlign = VAlign.Bottom
                    hAlign = HAlign.Right
                } else {
                    white = false
                    x = rect.midX
                    #if os(OSX)
                        y = rect.minY
                        vAlign = VAlign.Top
                    #else
                        if layouter.rotated {
                            y = rect.minY
                            vAlign = VAlign.Bottom
                        } else {
                            y = rect.maxY
                            vAlign = VAlign.Top
                        }
                    #endif
                    hAlign = HAlign.Center
                }
                drawText(context: context, x: x, y: y, text: files[Int(file)], white: white, vAlign: vAlign, hAlign: hAlign)
            })
        }
        
        for rank: UInt in 0...7 {
            layouter.layout(file: 0, rank: rank, callback: { rect in
                let white: Bool
                let x, y : CGFloat
                let vAlign: VAlign
                let hAlign: HAlign
                if labelsInside {
                    white = rank % 2 == 0
                    x = rect.origin.x + 2
                    y = rect.maxY
                    vAlign = VAlign.Top
                    hAlign = HAlign.Left
                } else {
                    white = false
                    y = rect.midY
                    vAlign = VAlign.Center
                    if layouter.rotated {
                        x = rect.maxX + 2
                        hAlign = HAlign.Left
                    } else {
                        x = rect.origin.x - 2
                        hAlign = HAlign.Right
                    }
                }
                drawText(context: context, x: x, y: y, text: String(rank+1), white: white, vAlign: vAlign, hAlign: hAlign)
            })
        }
    }
    
    enum VAlign {
        case Top
        case Bottom
        case Center
    }

    enum HAlign {
        case Left
        case Right
        case Center
    }

    func drawText(context: CGContext, x: CGFloat, y _y: CGFloat, text: String, white: Bool, vAlign: VAlign = .Bottom, hAlign: HAlign = .Left) {
        context.saveGState()
        
        context.textMatrix = CGAffineTransform.identity;
        #if os(OSX)
            let y = _y
        #else
            context.translateBy(x: 0, y: bounds.size.height)
            context.scaleBy(x: 1.0, y: -1.0)
            let y = bounds.size.height - _y
        #endif
        
        let str = NSMutableAttributedString(string: text)
        
        str.addAttribute(NSAttributedStringKey(rawValue: kCTForegroundColorAttributeName as String),
                         value: white ? Color.white : Color.black , range: NSMakeRange(0,str.length))
        
        let fontRef = Font.systemFont(ofSize: layouter.fontSize, weight: Font.Weight.bold)
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
        case .Center:
            hoffset = -path.boundingBox.size.width/2
        }
        
        var voffset: CGFloat = 0
        switch vAlign {
        case .Top:
            voffset = -path.boundingBox.size.height
        case .Bottom:
            voffset = 0
        case .Center:
            voffset = -path.boundingBox.size.height/2
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

