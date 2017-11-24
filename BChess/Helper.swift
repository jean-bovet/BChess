//
//  Helper.swift
//  BChess
//
//  Created by Jean Bovet on 11/23/17.
//  Copyright © 2017 Jean Bovet. All rights reserved.
//

import Foundation

class Helper {
    func generateMoves(fen: String) {
        var board = Board()
        board.fen = fen

        let generator = MoveGenerator(board: board, color: .white)
        let moves = generator.generateMoves()
        
        for move in moves {
            let newBoard = board.move(move: move)
            print("\(newBoard)\n")
        }
    }
}
