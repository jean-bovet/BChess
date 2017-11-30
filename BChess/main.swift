//
//  main.swift
//  BChess
//
//  Created by Jean Bovet on 11/9/17.
//  Copyright © 2017 Jean Bovet. All rights reserved.
//

import Foundation

//initmagicmoves()
//let square: UInt32 = 4 + 4 * 8
//let occupancy: U64 = 0
//
//let moves = Bmagic(square, occupancy)
//
//var offset = 0
//
//var board = ""
//for rank in 0...7 {
//    for file in 0...7 {
//        let bit: UInt64 = 1
//        if moves & (UInt64)(bit << offset) > 0 {
//            board += "X"
//        } else {
//            board += "."
//        }
//        offset += 1
//    }
//    board += "\n"
//}
//
//print(moves)
//print(board)

//while true {
//    let p = flsll(Int64(moves))
//    if p == 0 {
//        break
//    }
//    print(p)
//}

let engine = FBoardEngine()
engine.generatePositions()

//let perf = Performance()
//perf.generate(depth: 4)
//
//print("\(perf.moveCount) moves in \(perf.timeElapsed) seconds: \(perf.movesPerSecond) m/s")
//let uci = UCI()
//uci.run()

