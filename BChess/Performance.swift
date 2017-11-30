//
//  Performance.swift
//  BChess
//
//  Created by Jean Bovet on 11/26/17.
//  Copyright © 2017 Jean Bovet. All rights reserved.
//

import Foundation

class Performance {

    var moveCount = 0
    var timeElapsed = 0.0
    var movesPerSecond = 0
    
    func generate(depth: Int) {
        let before = DispatchTime.now()
        
        var board = Board()
        board.fen = StartPosFEN
        
        let generator = MoveGenerator(board: board, color: .white)
        _generate(generator: generator, depth: depth)
        
        let after = DispatchTime.now()
        
        let diff = after.uptimeNanoseconds - before.uptimeNanoseconds
        let movesPerSingleNanosecond = Double(moveCount) / Double(diff)
        
        movesPerSecond = Int(movesPerSingleNanosecond * 1e9)
        timeElapsed = Double(diff) / Double(1e9) // seconds
    }
    
    func _generate(generator: MoveGenerator, depth: Int) {
        if depth == 0 {
            return
        }
        
        let moves = generator.generateMoves()
        for move in moves {
            moveCount += 1
            let newBoard = generator.board.newBoard(withMove: move)
            let newGenerator = MoveGenerator(board: newBoard, color: newBoard.color)
            _generate(generator: newGenerator, depth: depth - 1)
        }
    }
}
