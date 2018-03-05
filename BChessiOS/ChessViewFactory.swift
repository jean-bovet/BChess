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
}

