//
//  FEngineTests.swift
//  BChessTests
//
//  Created by Jean Bovet on 5/10/21.
//  Copyright © 2021 Jean Bovet. All rights reserved.
//

import XCTest

class FEngineTests: XCTestCase {

    override func setUpWithError() throws {
        // Put setup code here. This method is called before the invocation of each test method in the class.
    }

    override func tearDownWithError() throws {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
    }

    func testTreeNode() throws {
        let engine = FEngine()
        engine.setPGN("1. e4 e5 (1... c5)")
        
        let nodes = engine.moveNodesTree()
        XCTAssertEqual(2, nodes.count)
        XCTAssertEqual("e4", nodes[0].name)
        XCTAssertEqual("e5", nodes[1].name)
        XCTAssertEqual("c5", nodes[1].variations[0].name)
    }

    func testTreeNode2() throws {
        let engine = FEngine()
        engine.setPGN("1.e4 e5 ( 1...Nf6 ) ( 1...Nc6 2.d4 Nf6 ) 2.Nf3 Nc6 3.Nc3 Nf6 *")
        
        let nodes = engine.moveNodesTree()
        XCTAssertEqual(6, nodes.count)
    }

}
