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

    override func viewDidLoad() {
        super.viewDidLoad()

        // Do any additional setup after loading the view.
    }

    override func viewDidLayout() {
        super.viewDidLayout()
        layoutBoardViews(boardSize: self.view.bounds.size)
    }
    
    func layoutBoardViews(boardSize: CGSize) {
        layoutBoard(boardSize: boardSize) { (frame, rank, file, blackBackground) in
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
        
        layoutBoard(boardSize: boardSize) { (frame, rank, file, blackBackground) in
            let view = pieceSquareView(rank: rank, file: file)
            view.frame = NSInsetRect(frame, 2, 2)
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
            view.tag = 200 + rank * 8 + file
            self.view.addSubview(view)
            return view
        }
    }

    func layoutBoard(boardSize: CGSize, callback: (_ frame: CGRect, _ rank: Int, _ file: Int, _ blackBackground: Bool) -> Void) {
        let width = round(boardSize.width/8);
        let height = round(boardSize.height/8);
        let size = min(width, height);
        
        var black = true
        for rank in 0...7 {
            for file in 0...7 {
                let frame = NSMakeRect(CGFloat(file)*size, CGFloat(rank)*size, size, size)
                callback(frame, rank, file, black)
                black = !black
            }
            black = !black
        }
    }
}

