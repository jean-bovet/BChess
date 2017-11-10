//
//  Board.swift
//  BChess
//
//  Created by Jean Bovet on 11/9/17.
//  Copyright © 2017 Jean Bovet. All rights reserved.
//

import Foundation

enum Color: Int {
    case white
    case black
    
    func inverse() -> Color {
        switch self {
        case .white:
            return .black
        case .black:
            return .white
        }
    }
}

enum PieceType: Double {
    case none
    case pawn
    case bishop
    case knight
    case rook
    case queen
    case king
}

func ==(lhs: Piece, rhs: Piece) -> Bool {
    return lhs.type == rhs.type && lhs.color == rhs.color
}

struct Piece: CustomStringConvertible {
    let type: PieceType
    let color: Color
    
    var description: String {
        return "\(type) \(color)"
    }

    var fenString: String {
        let pieceName: String
        switch type {
        case .none:
            pieceName = "-"
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
    
    static func empty() -> Piece {
        return Piece(type: .none, color: .white)
    }
}

struct Board: CustomStringConvertible {
    var cells = [Piece](repeating: Piece.empty(), count: 64)
    
    subscript(cursor: Cursor) -> Piece {
        get {
            return cells[cursor.rank*8+cursor.file]
        }
        set {
            cells[cursor.rank*8+cursor.file] = newValue
        }
    }
    
    subscript(rank: Int, file: Int) -> Piece {
        get {
            return cells[rank*8+file]
        }
        set {
            cells[rank*8+file] = newValue
        }
    }
    
    var description: String {
        var text = ""
        for rank in (0...7).reversed() {
            for file in 0...7 {
                let piece = self[rank, file]
                text += piece.fenString
            }
            text += "\n"
        }
        return text
    }

}

struct Cursor {
    var rank = 0
    var file = 0
    
    func offsetBy(rank rankValue: Int) -> Cursor {
        return Cursor(rank: rank + rankValue, file: file)
    }
    
    var isValid: Bool {
        return rank >= 0 && rank <= 7 && file >= 0 && file <= 7
    }
}

extension Board {

    func move(from c1: Cursor, to c2: Cursor) -> Board {
        var newBoard = Board(cells: Array(cells))
        newBoard[c2] = newBoard[c1]
        newBoard[c1] = Piece.empty()
        return newBoard
    }

}

class FENParser {
    
    let fen: String
    
    init(fen: String) {
        self.fen = fen
    }
    
    func parse() -> Board? {
        let fields = fen.split(separator: " ")
        guard let pieces = fields.first else {
            return nil
        }
        
        var board = Board()
        var cursor = Cursor()
        cursor.rank = 7
        
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

let StartPosFEN = "rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1"

