//
//  CPPTests.swift
//  BChessTests
//
//  Created by Jean Bovet on 12/7/17.
//  Copyright © 2017 Jean Bovet. All rights reserved.
//

import XCTest

class CPPTests: XCTestCase {

    func testMoves() {
        FEngine.runCPPTestMoves()
    }
    
    func testPGN() {
        FEngine.runCPPTestPGN()
    }

}
