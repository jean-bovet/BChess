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
        
        let info = engine.opening(for: "1. e4 c5")

        XCTAssertEqual(54, info!["Score"] as! Int)
        XCTAssertEqual("Sicilian defense", info!["Name"] as! String)
        XCTAssertEqual("B20", info!["ECO"] as! String)
    }
}
