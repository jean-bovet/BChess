//
//  FEngineTests.swift
//  BChessTests
//
//  Created by Jean Bovet on 5/10/21.
//  Copyright © 2021 Jean Bovet. All rights reserved.
//

import Testing

struct FEngineTests {

    @Test func treeNode() {
        let engine = FEngine()
        engine.setPGN("1. e4 e5 (1... c5)")
        
        let nodes = engine.moveNodesTree()
        #expect(nodes.count == 2)
        #expect(nodes[0].name == "e4")
        #expect(nodes[1].name == "e5")
        #expect(nodes[1].variations[0].name == "c5")
    }

    @Test func treeNode2() {
        let engine = FEngine()
        engine.setPGN("1.e4 e5 ( 1...Nf6 ) ( 1...Nc6 2.d4 Nf6 ) 2.Nf3 Nc6 3.Nc3 Nf6 *")
        
        let nodes = engine.moveNodesTree()
        #expect(nodes.count == 6)
    }

}
