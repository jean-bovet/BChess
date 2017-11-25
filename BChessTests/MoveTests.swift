//
//  BChessTests.swift
//  BChessTests
//
//  Created by Jean Bovet on 11/12/17.
//  Copyright © 2017 Jean Bovet. All rights reserved.
//

import XCTest

class MoveTests: XCTestCase {
    
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

    func testBlackKingCheckByKnight() {
        assertMoves("3r3k/5Npp/8/8/2Q5/1B6/8/7K b - - 1 1", [ "3r2k1/5Npp/8/8/2Q5/1B6/8/7K w - - 2 2" ], "h8")
    }
    
    func testBlackKingCheckByQueen() {
        assertMoves("3r2Qk/6pp/8/6N1/8/1B6/8/7K b - - 1 1", [ "6rk/6pp/8/6N1/8/1B6/8/7K w - - 0 2"])
    }
    
    func testBlackIsMate() {
        assertMoves("6rk/5Npp/8/8/8/1B6/8/7K b - - 1 2", [])
    }
    
    func assertMoves(_ initial: String, _ expected: [String], _ coordinate: String? = nil) {
        var initialBoard = Board()
        initialBoard.fen = initial
        
        let expectedBoards: [Board] = expected.map { var board = Board(); board.fen = $0; return board }
        let generator = MoveGenerator(board: initialBoard, color: initialBoard.color)
        if let coordinate = coordinate?.coordinate {
            let moves = generator.generateMoves(position: coordinate)
            let boards = moves.map { initialBoard.newBoard(withMove: $0) }
            
            assert(expectedBoards == boards)
        } else {
            let moves = generator.generateMoves()
            let boards = moves.map { initialBoard.newBoard(withMove: $0) }
            
            assert(expectedBoards == boards)
        }
    }

}
