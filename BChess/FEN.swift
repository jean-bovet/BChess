//
//  FEN.swift
//  BChess
//
//  Created by Jean Bovet on 11/10/17.
//  Copyright © 2017 Jean Bovet. All rights reserved.
//

import Foundation

class FENParser {
    
    let fen: String
    
    init(fen: String) {
        self.fen = fen
    }
    
    func parse() -> Board? {
        var fields = fen.split(separator: " ")
        guard fields.count == 6 else {
            return nil
        }
        
        let pieces = fields.removeFirst()
        
        var board = Board()
        var cursor = Coordinate()
        cursor.rank = Board.size - 1
        
        // 4k3/2r5/8/8/8/8/2R5/4K3 b - - 0 1
        let ranks = pieces.split(separator: "/")
        for rank in ranks {
            for p in rank {
                if let emptySquares = Int(String(p)) {
                    cursor.file = cursor.file + emptySquares
                } else if let piece = piece(for: p) {
                    board[cursor] = piece
                    cursor.file += 1
                } else {
                    print("Invalid FEN entry \(p) with \(fen)")
                    cursor.file += 1
                }
            }
            cursor.rank -= 1
            cursor.file = 0
        }
        
        let sideToMove = fields.removeFirst()
        board.color = (sideToMove == "w") ? .white : .black
        
        return board
    }
    
    func piece(for p: Character) -> Piece? {
        switch p {
        case "p":
            return Piece(type: .pawn, color: .black)
        case "P":
            return Piece(type: .pawn, color: .white)
            
        case "r":
            return Piece(type: .rook, color: .black)
        case "R":
            return Piece(type: .rook, color: .white)
            
        case "n":
            return Piece(type: .knight, color: .black)
        case "N":
            return Piece(type: .knight, color: .white)
            
        case "b":
            return Piece(type: .bishop, color: .black)
        case "B":
            return Piece(type: .bishop, color: .white)
            
        case "q":
            return Piece(type: .queen, color: .black)
        case "Q":
            return Piece(type: .queen, color: .white)
            
        case "k":
            return Piece(type: .king, color: .black)
        case "K":
            return Piece(type: .king, color: .white)
            
        default:
            return nil
        }
    }
}

extension String {
    func board() -> Board? {
        return FENParser(fen: self).parse()
    }
}

let StartPosFEN = "rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1"
