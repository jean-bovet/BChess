//
//  OpeningTests.swift
//  BChessTests
//
//  Created by Jean Bovet on 12/29/17.
//  Copyright © 2017 Jean Bovet. All rights reserved.
//

import XCTest

class OpeningTests: XCTestCase {

    func testLoading() throws {
        let path = Bundle(for: type(of: self)).path(forResource: "Openings", ofType: "pgn")
        XCTAssertNotNil(path)
        
        let pgn = try String(contentsOfFile: path!)
        XCTAssertNotNil(pgn)

        let engine = FEngine()
        XCTAssertTrue(engine.loadOpening(pgn))
    }
}
