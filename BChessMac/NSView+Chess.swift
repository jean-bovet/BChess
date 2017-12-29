//
//  NSView+Chess.swift
//  BChessMac
//
//  Created by Jean Bovet on 12/28/17.
//  Copyright © 2017 Jean Bovet. All rights reserved.
//

import Cocoa

extension NSView {
    
    func pieceSquareView(rank: Int, file: Int, action: Selector? = nil) -> PieceView {
        if let view = viewWithTag(200 + rank * 8 + file) as? PieceView {
            return view
        } else {
            let view = PieceView()
            view.wantsLayer = true
            view.addGestureRecognizer(NSClickGestureRecognizer(target: self, action: action))
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
    
    static let pieceImageNames = [
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
    
    func image(forPiece piece: String?) -> NSImage? {
        guard let piece = piece else {
            return nil
        }
        
        if let imageName = NSView.pieceImageNames[piece] {
            return NSImage(named: NSImage.Name(rawValue: imageName))
        } else {
            return nil
        }
    }
}

