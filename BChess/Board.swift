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

    var white: Bool {
        return color == .white
    }
    
    var description: String {
        return "\(type) \(color)"
    }

    var unicodeString: String {
        let pieceName: String
        switch type {
        case .none:
            pieceName = "."
        case .pawn:
            pieceName = white ? "♙" : "♟"
        case .rook:
            pieceName = white ? "♖" : "♜"
        case .knight:
            pieceName = white ? "♘" : "♞"
        case .bishop:
            pieceName = white ? "♗" : "♝"
        case .queen:
            pieceName = white ? "♕" : "♛"
        case .king:
            pieceName = white ? "♔" : "♚"
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
    
    var value: Int {
        switch type {
        case .none:
            return 0
        case .pawn:
            return 1
        case .rook:
            return 5
        case .knight:
            return 3
        case .bishop:
            return 3
        case .queen:
            return 9
        case .king:
            return 0
        }
    }
    
    var isEmpty: Bool {
        return type == .none
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
//                text += piece.fenString
                text += piece.unicodeString
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
        return offsetBy(rank: rankValue, file: 0)
    }
    
    func offsetBy(rank rankValue: Int, file fileValue: Int) -> Cursor {
        return Cursor(rank: rank + rankValue, file: file + fileValue)
    }

    var isValid: Bool {
        return rank >= 0 && rank <= 7 && file >= 0 && file <= 7
    }
}

func letter(forFile file: Int) -> String {
    switch file {
    case 0:
        return "a"
    case 1:
        return "b"
    case 2:
        return "c"
    case 3:
        return "d"
    case 4:
        return "e"
    case 5:
        return "f"
    case 6:
        return "g"
    case 7:
        return "h"
    default:
        return "?"
    }
}

extension Cursor: CustomStringConvertible {
    
    var description: String {
        let fileLetter = letter(forFile: file)
        return "\(fileLetter)\(rank+1)"
    }
}

struct BoardIterator: IteratorProtocol {

    let board: Board
    var cursor: Cursor
    
    init(board: Board, cursor: Cursor) {
        self.board = board
        self.cursor = cursor
    }
    
    mutating func next() -> (Piece, Cursor)? {
        cursor.file += 1
        if cursor.file > 7 {
            cursor.file = 0
            cursor.rank += 1
            if cursor.rank > 7 {
                return nil
            }
        }
        return (board[cursor], cursor)
    }
}

extension Board: Sequence {

    func makeIterator() -> BoardIterator {
        return BoardIterator(board: self, cursor: Cursor(rank: 0, file: 0))
    }
    
    func move(from c1: Cursor, to c2: Cursor) -> Board {
        var newBoard = Board(cells: Array(cells))
        newBoard[c2] = newBoard[c1]
        newBoard[c1] = Piece.empty()
        return newBoard
    }

    func isCheck(color: Color) -> Bool {
        // Find the king
        for (piece, cursor) in self {
            guard piece.type == .king && piece.color == color else {
                continue
            }
            
            // Find out if the king is attacked
            return isAttacked(cursor: cursor)
        }
        
        return false
    }
    
    func isAttacked(cursor: Cursor) -> Bool {
        let piece = self[cursor]
        let color = piece.color
        let attackingColor = piece.color.inverse()
        
        if color == .white {
            // Is piece attacked by black pawns?
        } else {
            // Is piece attacked by white pawns?
            if pawn(at: cursor.offsetBy(rank: -1, file: -1), color: attackingColor) {
                return true
            }
            if pawn(at: cursor.offsetBy(rank: -1, file: 1), color: attackingColor) {
                return true
            }
        }

        // Attacked by knight?
        let knightCursors = MoveGenerator.knightCursors(at: cursor)
        for cursor in knightCursors {
            if cursor.isValid && knight(at: cursor, color: attackingColor) {
                return true
            }
        }

        // Attacked by bishop, rook or queen?
        
        return false
    }
    
    func pawn(at cursor: Cursor, color: Color) -> Bool {
        return piece(at: cursor, type: .pawn, color: color)
    }
    
    func knight(at cursor: Cursor, color: Color) -> Bool {
        return piece(at: cursor, type: .knight, color: color)
    }

    func piece(at cursor: Cursor, type: PieceType, color: Color) -> Bool {
        let piece = self[cursor]
        return piece.type == type && piece.color == color
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

