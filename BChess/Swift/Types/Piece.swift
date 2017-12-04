//
//  Piece.swift
//  BChess
//
//  Created by Jean Bovet on 11/10/17.
//  Copyright © 2017 Jean Bovet. All rights reserved.
//

import Foundation

struct Piece {
    let type: PieceType
    let color: Color
    
    static let None = Piece(type: .none, color: .white)

    var isWhite: Bool {
        return color == .white
    }
    
    var isEmpty: Bool {
        return type == .none
    }
    
}

extension Piece: Equatable {
    static func ==(lhs: Piece, rhs: Piece) -> Bool {
        return lhs.type == rhs.type && lhs.color == rhs.color
    }
}

extension Piece: CustomStringConvertible {
    
    var unicodeString: String {
        let pieceName: String
        switch type {
        case .none:
            pieceName = "."
        case .pawn:
            pieceName = isWhite ? "♙" : "♟"
        case .rook:
            pieceName = isWhite ? "♖" : "♜"
        case .knight:
            pieceName = isWhite ? "♘" : "♞"
        case .bishop:
            pieceName = isWhite ? "♗" : "♝"
        case .queen:
            pieceName = isWhite ? "♕" : "♛"
        case .king:
            pieceName = isWhite ? "♔" : "♚"
        }
        return pieceName
    }
    
    var description: String {
        return "\(type) \(color)"
    }
    
}
