//
//  FEN.swift
//  BChess
//
//  Created by Jean Bovet on 11/10/17.
//  Copyright © 2017 Jean Bovet. All rights reserved.
//

import Foundation

// https://en.wikipedia.org/wiki/Forsyth–Edwards_Notation
let StartPosFEN = "rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1"

extension Castling {
    
    var fen: String {
        get {
            var s = ""
            if whiteKingSide {
                s += "K"
            }
            if whiteQueenSide {
                s += "Q"
            }
            if blackKingSide {
                s += "k"
            }
            if blackQueenSide {
                s += "q"
            }
            if s.isEmpty {
                return "-"
            } else {
                return s
            }
        }
        set (value) {
            whiteKingSide = value.contains("K")
            whiteQueenSide = value.contains("Q")
            blackKingSide = value.contains("k")
            blackQueenSide = value.contains("q")
        }
    }
    
}

extension Character {
    var piece: Piece? {
        switch self {
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

extension Piece {
    
    var fen: Character {
        let pieceName: Character
        switch type {
        case .none:
            pieceName = "."
        case .pawn:
            pieceName = isWhite ? "P" : "p"
        case .rook:
            pieceName = isWhite ? "R" : "r"
        case .knight:
            pieceName = isWhite ? "N" : "n"
        case .bishop:
            pieceName = isWhite ? "B" : "b"
        case .queen:
            pieceName = isWhite ? "Q" : "q"
        case .king:
            pieceName = isWhite ? "K" : "k"
        }
        return pieceName
    }
    
}

extension Board {
    
    var fen: String {
        get {
            // "rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1"
            var fen = ""
            for rank in (0...7).reversed() {
                var emptyCount = 0
                for file in 0...7 {
                    let piece = self[rank, file]
                    if piece.isEmpty {
                        emptyCount += 1
                    } else {
                        if emptyCount > 0 {
                            fen += String(emptyCount)
                            emptyCount = 0
                        }
                        fen += String(piece.fen)
                    }
                }
                
                if emptyCount > 0 {
                    fen += String(emptyCount)
                    emptyCount = 0
                }
                
                if rank > 0 {
                    fen += "/"
                }
            }
            
            // Color to move
            if color == .white {
                fen += " w"
            } else {
                fen += " b"
            }
            
            // Castling availability
            fen += " \(castling.fen)"
            
            // En passant
            // TODO
            fen += " -"
            
            // Halfmove
            // TODO
            fen += " 0"
            
            // Full move number (starting at 1)
            fen += " \(fullMoveCount)"
            
            return fen
        }
        set {
            var fields = newValue.split(separator: " ")
            assert(fields.count == 6, "Expected 6 fields for FEN")
            
            let pieces = fields.removeFirst()
            
            var cursor = Coordinate()
            cursor.rank = Board.size - 1
            
            // 4k3/2r5/8/8/8/8/2R5/4K3 b - - 0 1
            let ranks = pieces.split(separator: "/")
            for rank in ranks {
                for p in rank {
                    if let emptySquares = Int(String(p)) {
                        for _ in 1...emptySquares {
                            self[cursor] = .None
                            cursor.file += 1
                        }
                    } else if let piece = p.piece {
                        self[cursor] = piece
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
            color = (sideToMove == "w") ? .white : .black
            
            // KQkq
            let castlingAvailability = fields.removeFirst()
            castling.fen = String(castlingAvailability)
            
            // En passant
            fields.removeFirst()
            
            // Half move
            fields.removeFirst()
            
            // Full move
            let fullMove = fields.removeFirst()
            fullMoveCount = Int(fullMove)!
        }
    }
}

