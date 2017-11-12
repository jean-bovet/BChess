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
    
    var isWhite: Bool {
        return color == .white
    }
    
    var isEmpty: Bool {
        return type == .none
    }
    
    static func empty() -> Piece {
        return Piece(type: .none, color: .white)
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
    
    var fenString: String {
        let pieceName: String
        switch type {
        case .none:
            pieceName = "."
        case .pawn:
            pieceName = "p"
        case .rook:
            pieceName = "r"
        case .knight:
            pieceName = "n"
        case .bishop:
            pieceName = "b"
        case .queen:
            pieceName = "q"
        case .king:
            pieceName = "k"
        }
        if color == .white {
            return pieceName.uppercased()
        } else {
            return pieceName
        }
    }
    
    var description: String {
        return "\(type) \(color)"
    }
    
}
