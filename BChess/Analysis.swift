//
//  Analysis.swift
//  BChess
//
//  Created by Jean Bovet on 11/9/17.
//  Copyright © 2017 Jean Bovet. All rights reserved.
//

import Foundation

class Analysis {
    
    func generateMoves(board: Board, color: Color) -> [Board] {
        var boards = [Board]()
        for rank in 0...7 {
            for file in 0...7 {
                let piece = board[rank, file]
                if piece.type == .pawn && piece.color == color {
                    boards.append(contentsOf: generatePawnMoves(board: board, color: color, cursor: Cursor(rank: rank, file: file)))
                }
            }
        }
        return boards
    }
    
    func generatePawnMoves(board: Board, color: Color, cursor: Cursor) -> [Board] {
        var boards = [Board]()
        let cursors = generatePawnCursors(board: board, cursor: cursor, color: color)
        for c in cursors {
            boards.append(board.move(from: cursor, to: c))
        }
        return boards
    }
    
    func generatePawnCursors(board: Board, cursor: Cursor, color: Color) -> [Cursor] {
        var cursors = [Cursor]()
        if color == .white {
            cursors.append(cursor.offsetBy(rank: 1), board: board, color: color)
            cursors.append(cursor.offsetBy(rank: 2), board: board, color: color)
        } else {
            cursors.append(cursor.offsetBy(rank: -1), board: board, color: color)
            cursors.append(cursor.offsetBy(rank: -2), board: board, color: color)
        }
        return cursors
    }
    
}

extension Array where Iterator.Element == Cursor {
    
    mutating func append(_ c: Cursor, board: Board, color: Color) {
        guard c.isValid else {
            return
        }
                
        let piece = board[c]
        guard piece.type == .none || piece.color == color.inverse() else {
            return
        }

        append(c)
    }

}
