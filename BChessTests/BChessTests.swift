//
//  BChessTests.swift
//  BChessTests
//
//  Created by Jean Bovet on 11/12/17.
//  Copyright © 2017 Jean Bovet. All rights reserved.
//

import XCTest

class BChessTests: XCTestCase {
    
    func testPawnMoves() {
        assertMoves("8/8/8/8/8/8/2P5/8 w - - 0 1",
                  [
                    "8/8/8/8/8/2P5/8/8 w - - 0 1",
                    "8/8/8/8/2P5/8/8/8 w - - 0 1"
            ])
        
        assertMoves("8/8/8/8/2P5/8/8/8 w - - 0 1",
                  [ "8/8/8/2P5/8/8/8/8 w - - 0 1"])
        
    }
    
    func testKnight() {
        assertMoves("8/8/8/3N4/8/8/8/8 w - - 0 1",
                    ["8/2N5/8/8/8/8/8/8 w - - 0 1",
                     "8/4N3/8/8/8/8/8/8 w - - 0 1",
                     "8/8/5N2/8/8/8/8/8 w - - 0 1",
                     "8/8/8/8/5N2/8/8/8 w - - 0 1",
                     "8/8/8/8/8/4N3/8/8 w - - 0 1",
                     "8/8/8/8/8/2N5/8/8 w - - 0 1",
                     "8/8/8/8/1N6/8/8/8 w - - 0 1",
                     "8/8/1N6/8/8/8/8/8 w - - 0 1"
                     ],
                    "d5")
    }

    func testKnightInCorner() {
        assertMoves("8/8/8/8/8/8/8/N7 w - - 0 1",
                    ["8/8/8/8/8/1N6/8/8 w - - 0 1",
                     "8/8/8/8/8/8/2N5/8 w - - 0 1"],
                    "a1")
    }
    
    func testKnightWithPawns() {
        assertMoves("8/8/1P3p2/3N4/8/8/8/8 w - - 0 1",
                  ["8/2N5/1P3p2/8/8/8/8/8 w - - 0 1",
                   "8/4N3/1P3p2/8/8/8/8/8 w - - 0 1",
                   "8/8/1P3N2/8/8/8/8/8 w - - 0 1",
                   "8/8/1P3p2/8/5N2/8/8/8 w - - 0 1",
                   "8/8/1P3p2/8/8/4N3/8/8 w - - 0 1",
                   "8/8/1P3p2/8/8/2N5/8/8 w - - 0 1",
                   "8/8/1P3p2/8/1N6/8/8/8 w - - 0 1"],
                  "d5")
    }

    func assertMoves(_ initial: String, _ expected: [String], _ coordinate: String? = nil) {
        let initialBoard = initial.board()!
        let expectedBoards = expected.map { $0.board()! }
        let generator = MoveGenerator(board: initialBoard, color: .white)
        if let coordinate = coordinate?.coordinate {
            let moves = generator.generateMoves(position: coordinate)
            let boards = moves.map { initialBoard.move(move: $0) }
            
            assert(expectedBoards == boards)
        } else {
            let moves = generator.generateMoves()
            let boards = moves.map { initialBoard.move(move: $0) }
            
            assert(expectedBoards == boards)
        }
    }

}
