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
        let board = StartPosFEN.board()
        XCTAssertNotNil(board)
        
        let fen = board?.toFEN()
        XCTAssertEqual(fen, StartPosFEN)
        
        let again = fen?.board()?.toFEN()
        XCTAssertEqual(again, StartPosFEN)
    }

}
