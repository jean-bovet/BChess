//
//  ChessView.swift
//  BChessMac
//
//  Created by Jean Bovet on 12/11/17.
//  Copyright © 2017 Jean Bovet. All rights reserved.
//

import Cocoa

class BoardView: NSView {
    
    let engine = FEngine()

    let borderView = NSView()
    
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
    
    var playAgainstComputer : PlayAgainst = .black {
        didSet {
            playEngineIfPossible()
        }
    }
    
    var boardSquareSize: CGFloat = 0
    var boardSquareDX: CGFloat = 0
    var boardSquareDY: CGFloat = 0
    
    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
    }
    
    required init?(coder decoder: NSCoder) {
        super.init(coder: decoder)
        numberFormatter.numberStyle = .decimal
        numberFormatter.thousandSeparator = ","
        numberFormatter.hasThousandSeparators = true
        
        borderView.wantsLayer = true
        borderView.layer?.borderColor = NSColor.black.cgColor
        borderView.layer?.borderWidth = 1
        
        addSubview(borderView)
    }
    
    override func layout() {
        super.layout()
        
        // Don't layout the UI if there is an animation in progress
        // to avoid cancelling the animation.
        guard !animation else {
            return
        }
        
        var size = bounds.size
        size.width -= 50
        size.height -= 50
        computeSizes(boardSize: size)
        layoutBoardViews()
        
        borderView.frame = NSInsetRect(NSMakeRect(boardSquareDX, boardSquareDY, 8*boardSquareSize, 8*boardSquareSize), -1, -1)
    }
    
    // MARK: Functions
    
    func newGame() {
        clearEngineMoveIndicators()
        clearAllViewIndicators()
        
        engine.setFEN(StartPosFEN)
        invalidateUI()
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
    
    func boardSquareView(rank: Int, file: Int, blackSquare: Bool = false) -> BoardSquareView {
        if let squareView = viewWithTag(100+rank*8+file) as? BoardSquareView {
            return squareView
        } else {
            let squareView = BoardSquareView(frame: frame)
            squareView.rank = rank
            squareView.file = file
            squareView.wantsLayer = true
            squareView.blackSquare = blackSquare
            addSubview(squareView)
            return squareView
        }
    }
    
    func clearAllViewIndicators() {
        for pieceView in subviews.filter({ $0 is PieceView }).map( {$0 as! PieceView }) {
            pieceView.clear()
        }
    }
    
    func clearEngineMoveIndicators() {
        for pieceView in subviews.filter({ $0 is BoardSquareView }).map( {$0 as! BoardSquareView }) {
            pieceView.clear()
        }
    }

    func playEngineIfPossible() {
        if engine.isWhite() && playAgainstComputer == .white {
            enginePlay()
        }
        if !engine.isWhite() && playAgainstComputer == .black {
            enginePlay()
        }
    }
    
    // MARK: Actions
    
    @objc func pieceSquareViewTapped(sender: NSClickGestureRecognizer) {
        if let view = sender.view as? PieceView {
            if view.moveIndicator {
                // Perform move
                engine.move(view.move!.rawMoveValue)
                clearAllViewIndicators()
                clearEngineMoveIndicators()
                invalidateUI()
                playEngineIfPossible()
            } else if view.selected {
                clearAllViewIndicators()
                needsLayout = true
            } else {
                clearAllViewIndicators()
                
                // Select the square
                view.selected = true
                
                let moves = engine.moves(at: UInt(view.rank), file: UInt(view.file))
                for move in moves {
                    let moveView = pieceSquareView(rank: Int(move.toRank), file: Int(move.toFile))
                    moveView.moveIndicator = true
                    moveView.move = move
                }
            }
            self.needsDisplay = true
        }
    }
    
    // MARK: Actions
    
    var info: FEngineInfo? = nil
    
    func enginePlay() {
        engine.evaluate() { (info, completed) in
            self.info = info
            if completed {
                DispatchQueue.main.async {
                    self.animateMove(info: info)
                }
            }
        }
    }
    
    func boldText(text: String) -> NSAttributedString {
        return NSAttributedString(string: text, attributes: [ NSAttributedStringKey.font : NSFont.boldSystemFont(ofSize: 12)])
    }
    
    func regularText(text: String) -> NSAttributedString {
        return NSAttributedString(string: text, attributes: [ NSAttributedStringKey.font : NSFont.systemFont(ofSize: 12)])
    }

    var infoLine: NSAttributedString {
        let infoColorToPlay = engine.isWhite() ? "White" : "Black"

        if let info = info {
            let lineInfo = info.bestLine(false)
            let infoNodes = self.numberFormatter.string(from: NSNumber(value: info.nodeEvaluated))!
            let infoSpeed = self.numberFormatter.string(from: NSNumber(value: info.movesPerSecond))!
            let infoValue: String
            if info.mat {
                infoValue = "#"
            } else {
                infoValue = String(info.value)
            }
            let infoString = NSMutableAttributedString()
            infoString.append(boldText(text: "Side to play: "))
            infoString.append(regularText(text: infoColorToPlay))
            infoString.append(regularText(text: "\n"))

            infoString.append(boldText(text: "Value: "))
            infoString.append(regularText(text: infoValue))
            infoString.append(regularText(text: "\n"))

            infoString.append(boldText(text: "Line: "))
            infoString.append(regularText(text: lineInfo))
            infoString.append(regularText(text: "\n"))

            infoString.append(boldText(text: "Depth: "))
            infoString.append(regularText(text: "\(info.depth)/\(info.quiescenceDepth)"))
            infoString.append(regularText(text: "\n"))

            infoString.append(boldText(text: "Nodes: "))
            infoString.append(regularText(text: infoNodes))
            infoString.append(regularText(text: "\n"))

            infoString.append(boldText(text: "Speed: "))
            infoString.append(regularText(text: "\(infoSpeed) n/s"))
            return infoString
        } else {
            let infoString = NSMutableAttributedString()
            infoString.append(boldText(text: "Side to play: "))
            infoString.append(regularText(text: infoColorToPlay))
            return infoString
        }
    }
    
    var animation = false
    
    func animateMove(info: FEngineInfo) {
        // Do not try to animate an invalid move, which can happen
        // when there is a stale or mate and no move is found by
        // the chess engine.
        guard info.bestMove != 0 else {
            return
        }
        
        animation = true
        
        let fromPieceView = pieceSquareView(rank: Int(info.fromRank), file: Int(info.fromFile))
        let targetPieceView = pieceSquareView(rank: Int(info.toRank), file: Int(info.toFile))
        
        let fromSquareView = boardSquareView(rank: Int(info.fromRank), file: Int(info.fromFile))
        let targetSquareView = boardSquareView(rank: Int(info.toRank), file: Int(info.toFile))
        fromSquareView.fromIndicator = true
        targetSquareView.toIndicator = true

        NSAnimationContext.runAnimationGroup({ _ in
            NSAnimationContext.current.duration = 0.5
            NSAnimationContext.current.timingFunction = CAMediaTimingFunction(name: kCAAnimationLinear)
        
            targetPieceView.animator().alphaValue = 0.0
            fromPieceView.animator().frame = targetPieceView.frame
        }, completionHandler: {
            self.animation = false
            targetPieceView.alphaValue = 1.0
            self.engine.move(info.bestMove)
        })
    }
    
    // MARK: Layout
    
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
    
    func layoutBoardViews() {
        layoutLabels()
        
        layoutBoard() { (frame, rank, file, blackBackground) in
            let squareView = boardSquareView(rank: rank, file: file, blackSquare: blackBackground)
            squareView.frame = frame
        }
        
        layoutBoard() { (frame, rank, file, blackBackground) in
            let view = pieceSquareView(rank: rank, file: file)
            view.frame = frame
            if let piece = engine.piece(at: UInt(rank), file: UInt(file)) {
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
    
    // MARK: Rank and File Labels
    
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
    
    func invalidateUI() {
        needsLayout = true
    }
    
}
