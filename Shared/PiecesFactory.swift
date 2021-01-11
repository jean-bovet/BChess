//
//  PiecesFactory.swift
//  BChess
//
//  Created by Jean Bovet on 1/10/21.
//  Copyright © 2021 Jean Bovet. All rights reserved.
//

import Foundation

struct Piece {
    let name: String
    let file: UInt
    let rank: UInt
}

extension Piece {
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
    
    var imageName: String {
        let pieceImageName = String(name.prefix(1))
        return Piece.pieceImageNames[pieceImageName]!
    }
}

extension Array where Element == Piece {
    func piece(atRank rank: Int, file: Int) -> Piece? {
        return filter { $0.rank == rank && $0.file == file }.first
    }
}

struct PiecesFactory {
    
    func pieces(forState state: String) -> [Piece] {
        var pieces = [Piece]()
        var cursor = state.startIndex
        while cursor < state.endIndex {
            let nextCursor = state.index(cursor, offsetBy: 4)
            let token = state[cursor..<nextCursor]
            pieces.append(piece(forToken: String(token)))
            cursor = nextCursor
        }
        return pieces
    }
    
    func piece(forToken token: String) -> Piece {
        let pieceName = String(token.prefix(2))
        let pieceFile = UInt(String(token[token.index(token.startIndex, offsetBy: 2)]))!
        let pieceRank = UInt(String(token[token.index(token.startIndex, offsetBy: 3)]))!
        return Piece(name: pieceName, file: pieceFile, rank: pieceRank)
    }
                    
}
