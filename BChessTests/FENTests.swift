//
//  FENTests.swift
//  BChessTests
//
//  Created by Jean Bovet on 11/24/17.
//  Copyright © 2017 Jean Bovet. All rights reserved.
//

import XCTest

class FENTests: XCTestCase {

    func testInitialBoard() {
        var board = Board()
        board.fen = StartPosFEN
        
        let fen = board.fen
        XCTAssertEqual(fen, StartPosFEN)
        
        board.fen = fen
        let again = board.fen
        XCTAssertEqual(again, StartPosFEN)
    }

}
