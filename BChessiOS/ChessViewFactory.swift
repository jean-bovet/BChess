//
//  ChessViewFactory.swift
//  BChessiOS
//
//  Created by Jean Bovet on 3/4/18.
//  Copyright © 2018 Jean Bovet. All rights reserved.
//

import Foundation
import UIKit

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
    
    func pieceViews(forState state: String) -> [ChessViewPiece] {
        var pieces = [ChessViewPiece]()
        var cursor = state.startIndex
        while cursor < state.endIndex {
            let nextCursor = state.index(cursor, offsetBy: 4)
            let token = state[cursor..<nextCursor]
            pieces.append(pieceView(forToken: String(token)))
            cursor = nextCursor
        }
        return pieces
    }
    
    func pieceView(forToken token: String) -> ChessViewPiece {
        let pieceName = String(token.prefix(2))
        let pieceFile = UInt(String(token[token.index(token.startIndex, offsetBy: 2)]))!
        let pieceRank = UInt(String(token[token.index(token.startIndex, offsetBy: 3)]))!
        
        let pieceView = self.pieceView(forName: pieceName)
        
        return ChessViewPiece(name: pieceName, file: pieceFile, rank: pieceRank, view: pieceView)
    }
    
    func pieceView(forName name: String) -> UIView {
        let view = create(name: String(name.prefix(1)))
        return view
    }
    
}

