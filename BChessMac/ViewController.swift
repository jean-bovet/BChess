//
//  ViewController.swift
//  BChessMac
//
//  Created by Jean Bovet on 12/10/17.
//  Copyright © 2017 Jean Bovet. All rights reserved.
//

import Cocoa

class ViewController: NSViewController {

    let engine = UCIEngine()
    
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
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
    }
    
    override func viewDidLayout() {
        super.viewDidLayout()
        var size = self.view.bounds.size
        size.width -= 50
        size.height -= 50
        computeSizes(boardSize: size)
        layoutBoardViews()
    }
    
    func layoutBoardViews() {
        layoutLabels()
        
        layoutBoard() { (frame, rank, file, blackBackground) in
            if let squareView = self.view.viewWithTag(100+rank*8+file) {
                squareView.frame = frame
            } else {
                let squareView = BackgroundSquareView(frame: frame)
                squareView.rank = rank
                squareView.file = file
                squareView.wantsLayer = true
                if blackBackground {
                    squareView.layer?.backgroundColor = NSColor.gray.cgColor
                } else {
                    squareView.layer?.backgroundColor = NSColor(red: 0.9, green: 0.9, blue: 0.9, alpha: 1).cgColor
                }
                view.addSubview(squareView)
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
    
    func pieceSquareView(rank: Int, file: Int) -> PieceSquareView {
        if let view = self.view.viewWithTag(200 + rank * 8 + file) as? PieceSquareView {
            return view
        } else {
            let view = PieceSquareView()
            view.wantsLayer = true
            view.addGestureRecognizer(NSClickGestureRecognizer(target: self, action: #selector(pieceSquareViewTapped)))
            view.tag = 200 + rank * 8 + file
            view.rank = rank
            view.file = file
            self.view.addSubview(view)
            return view
        }
    }

    func clearAllViewIndicators() {
        for pieceView in self.view.subviews.filter({ $0 is PieceSquareView }).map( {$0 as! PieceSquareView }) {
            pieceView.moveIndicator = false
            pieceView.selected = false
        }
    }
    
    @objc func pieceSquareViewTapped(sender: NSClickGestureRecognizer) {
        if let view = sender.view as? PieceSquareView {
            if view.moveIndicator {
                // Perform move
                engine.engine.move(view.move!.rawMoveValue)
                clearAllViewIndicators()
                self.view.needsLayout = true
                enginePlay()
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
            self.view.needsDisplay = true
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
            view.addSubview(tf)
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
        engine.evaluate(depth: 5) { (info, completed) in
            if completed {
                self.engine.engine.move(info.rawMoveValue)
                DispatchQueue.main.async {
                    self.view.needsLayout = true
                }
            }
        }
    }
    
    var boardSquareSize: CGFloat = 0
    var boardSquareDX: CGFloat = 0
    var boardSquareDY: CGFloat = 0

    func computeSizes(boardSize: CGSize) {
        let width = round(boardSize.width/8)
        let height = round(boardSize.height/8)
        boardSquareSize = min(width, height)
        
        boardSquareDX = round((self.view.frame.size.width - CGFloat(8*boardSquareSize))/2)
        boardSquareDY = round((self.view.frame.size.height - CGFloat(8*boardSquareSize))/2)
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
    
    // MARK: Actions
    
    @IBAction func copy(_ sender: Any?) {
        let fen = engine.get()
        
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(fen, forType: .string)
    }
    
    @IBAction func paste(_ sender: Any?) {
        let pasteboard = NSPasteboard.general
        if let fen = pasteboard.string(forType: .string) {
            engine.set(fen: fen)
            self.view.needsLayout = true
        }
    }
}

