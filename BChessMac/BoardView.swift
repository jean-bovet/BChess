//
//  ChessView.swift
//  BChessMac
//
//  Created by Jean Bovet on 12/11/17.
//  Copyright © 2017 Jean Bovet. All rights reserved.
//

import Cocoa

protocol ChessViewInformationDelegate: class {
    func chessViewEngineInfoDidChange(info: String)
}

class BoardView: NSView {

    weak var delegate: ChessViewInformationDelegate? = nil
    
    let engine = UCIEngine()

    let numberFormatter = NumberFormatter()

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
    
    let ranks = [ "1", "2", "3", "4", "5", "6", "7", "8" ]
    let files = [ "a", "b", "c", "d", "e", "f", "g", "h" ]
    
    var labels = [String: NSTextField]()
    
    enum PlayAgainst {
        case white
        case black
        case human
    }
    
    var playAgainstComputer : PlayAgainst = .black
    var searchDepth = 4
    
    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
    }
    
    required init?(coder decoder: NSCoder) {
        super.init(coder: decoder)
        numberFormatter.numberStyle = .decimal
        numberFormatter.thousandSeparator = ","
        numberFormatter.hasThousandSeparators = true
    }
    
    override func encodeRestorableState(with coder: NSCoder) {
        super.encodeRestorableState(with: coder)
        coder.encode(engine.get(), forKey: "fen")
    }
    
    override func restoreState(with coder: NSCoder) {
        super.restoreState(with: coder)
        if let fen = coder.decodeObject(forKey: "fen") as? String {
            engine.set(fen: fen)
            self.needsLayout = true
        }
    }

    override func layout() {
        super.layout()
        var size = bounds.size
        size.width -= 50
        size.height -= 50
        computeSizes(boardSize: size)
        layoutBoardViews()
    }
    
    func newGame() {
        engine.newGame()
        invalidateUI()
    }
    
    func layoutBoardViews() {
        layoutLabels()
        
        layoutBoard() { (frame, rank, file, blackBackground) in
            if let squareView = viewWithTag(100+rank*8+file) {
                squareView.frame = frame
            } else {
                let squareView = BoardSquareView(frame: frame)
                squareView.rank = rank
                squareView.file = file
                squareView.wantsLayer = true
                if blackBackground {
                    squareView.layer?.backgroundColor = NSColor.gray.cgColor
                } else {
                    squareView.layer?.backgroundColor = NSColor(red: 0.9, green: 0.9, blue: 0.9, alpha: 1).cgColor
                }
                addSubview(squareView)
            }
        }
        
        layoutBoard() { (frame, rank, file, blackBackground) in
            let view = pieceSquareView(rank: rank, file: file)
            view.frame = frame
            if let piece = engine.engine.piece(at: UInt(rank), file: UInt(file)) {
                if let imageName = pieceImageNames[piece], let image = NSImage(named: NSImage.Name(rawValue: imageName)) {
                    view.image = image
                } else {
                    view.image = nil
                }
            } else {
                view.image = nil
            }
        }
        
    }
    
    func pieceSquareView(rank: Int, file: Int) -> PieceView {
        if let view = viewWithTag(200 + rank * 8 + file) as? PieceView {
            return view
        } else {
            let view = PieceView()
            view.wantsLayer = true
            view.addGestureRecognizer(NSClickGestureRecognizer(target: self, action: #selector(pieceSquareViewTapped)))
            view.tag = 200 + rank * 8 + file
            view.rank = rank
            view.file = file
            addSubview(view)
            return view
        }
    }
    
    func clearAllViewIndicators() {
        for pieceView in subviews.filter({ $0 is PieceView }).map( {$0 as! PieceView }) {
            pieceView.moveIndicator = false
            pieceView.selected = false
        }
    }
    
    @objc func pieceSquareViewTapped(sender: NSClickGestureRecognizer) {
        if let view = sender.view as? PieceView {
            if view.moveIndicator {
                // Perform move
                engine.engine.move(view.move!.rawMoveValue)
                clearAllViewIndicators()
                invalidateUI()
                if engine.engine.isWhite() && playAgainstComputer == .white {
                    enginePlay()
                }
                if !engine.engine.isWhite() && playAgainstComputer == .black {
                    enginePlay()
                }
            } else if view.selected {
                clearAllViewIndicators()
                self.needsLayout = true
            } else {
                clearAllViewIndicators()
                
                // Select the square
                view.selected = true
                
                let moves = engine.engine.moves(at: UInt(view.rank), file: UInt(view.file))
                for move in moves {
                    let moveView = pieceSquareView(rank: Int(move.toRank), file: Int(move.toFile))
                    moveView.moveIndicator = true
                    moveView.move = move
                }
            }
            self.needsDisplay = true
        }
    }
    
    func layoutLabels() {
        for (index, rank) in ranks.enumerated() {
            let label = textForLabel(label: rank)
            label.frame = NSMakeRect(boardSquareDX - label.frame.size.width - 2, boardSquareDY + CGFloat(index) * boardSquareSize + (boardSquareSize - label.frame.size.height)/2, label.frame.size.width, label.frame.size.height)
        }
        
        for (index, file) in files.enumerated() {
            let label = textForLabel(label: file)
            label.frame = NSMakeRect(boardSquareDX + CGFloat(index) * boardSquareSize + (boardSquareSize - label.frame.size.width)/2, boardSquareDY - label.frame.size.height - 2, label.frame.size.width, label.frame.size.height)
        }
    }
    
    func textForLabel(label: String) -> NSTextField {
        if let tf = labels[label] {
            return tf
        } else {
            let tf = NSTextField()
            addSubview(tf)
            tf.stringValue = label
            tf.isBezeled = false
            tf.drawsBackground = false
            tf.isEditable = false
            tf.isSelectable = false
            tf.sizeToFit()
            labels[label] = tf
            return tf
        }
    }
    
    func enginePlay() {
        engine.evaluate(depth: searchDepth) { (info, completed) in
            let lineInfo = info.bestLine.map { $0 }.joined(separator: " ")
            let infoNodes = self.numberFormatter.string(from: NSNumber(value: info.nodeEvaluated))!
            let infoSpeed = self.numberFormatter.string(from: NSNumber(value: info.movesPerSecond))!
            let infoString = "Line: \(lineInfo)   Value: \(info.value)   Depth: \(info.depth)   Nodes: \(infoNodes) at \(infoSpeed) n/s"
            self.delegate?.chessViewEngineInfoDidChange(info: infoString)
            if completed {
                DispatchQueue.main.async {
                    self.animateMove(info: info)
                }
            }
        }
    }
    
    func animateMove(info: FEngineInfo) {
        let fromPieceView = pieceSquareView(rank: Int(info.fromRank), file: Int(info.fromFile))
        let targetPieceView = pieceSquareView(rank: Int(info.toRank), file: Int(info.toFile))
        NSAnimationContext.runAnimationGroup({ _ in
            NSAnimationContext.current.duration = 0.5
            NSAnimationContext.current.timingFunction = CAMediaTimingFunction(name: kCAAnimationLinear)
            
            targetPieceView.animator().alphaValue = 0.0
            fromPieceView.animator().frame = targetPieceView.frame
        }, completionHandler:{
            targetPieceView.alphaValue = 1.0
            self.engine.engine.move(info.rawMoveValue)
            self.invalidateUI()
        })
    }
    
    var boardSquareSize: CGFloat = 0
    var boardSquareDX: CGFloat = 0
    var boardSquareDY: CGFloat = 0
    
    func computeSizes(boardSize: CGSize) {
        let width = round(boardSize.width/8)
        let height = round(boardSize.height/8)
        boardSquareSize = min(width, height)
        
        boardSquareDX = round((frame.size.width - CGFloat(8*boardSquareSize))/2)
        boardSquareDY = round((frame.size.height - CGFloat(8*boardSquareSize))/2)
    }
    
    func layoutBoard(callback: (_ frame: CGRect, _ rank: Int, _ file: Int, _ blackBackground: Bool) -> Void) {
        var black = true
        for rank in 0...7 {
            for file in 0...7 {
                let frame = NSMakeRect(CGFloat(file)*boardSquareSize+boardSquareDX, CGFloat(rank)*boardSquareSize+boardSquareDY, boardSquareSize, boardSquareSize)
                callback(frame, rank, file, black)
                black = !black
            }
            black = !black
        }
    }
    
    func invalidateUI() {
        needsLayout = true
        invalidateRestorableState()
    }
    
}
