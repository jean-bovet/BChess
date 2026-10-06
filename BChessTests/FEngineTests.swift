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

    @Test func gameEndCrossesTheBridge() {
        let engine = FEngine()
        #expect(engine.gameEnd == .none)

        engine.setPGN("1. f3 e5 2. g4 Qh4#")
        #expect(engine.gameEnd == .checkmate)
        #expect(!engine.canPlay())
    }

    @Test func moveUCIPlaysSpecialMoves() {
        // A promotion to a knight, not a pawn on the last rank
        let promotion = FEngine()
        promotion.setFEN("8/1P6/8/8/8/8/8/k3K3 w - - 0 1")
        #expect(promotion.move(uci: "b7b8n"))
        #expect(promotion.fen() == "1N6/8/8/8/8/8/8/k3K3 b - - 0 1")

        // En passant takes the pawn that was passed
        let enPassant = FEngine()
        enPassant.setFEN("4k3/8/8/3pP3/8/8/8/4K3 w - d6 0 1")
        #expect(enPassant.move(uci: "e5d6"))
        #expect(enPassant.fen() == "4k3/8/3P4/8/8/8/8/4K3 b - - 0 1")

        // Castling is written as the king move, and the rook follows
        let castling = FEngine()
        castling.setFEN("4k3/8/8/8/8/8/8/4K2R w K - 0 1")
        #expect(castling.move(uci: "e1g1"))
        #expect(castling.fen() == "4k3/8/8/8/8/8/8/5RK1 b - - 1 1")
    }

    @Test func moveUCIRejectsIllegal() {
        let engine = FEngine()
        engine.setFEN("8/1P6/8/8/8/8/8/k3K3 w - - 0 1")
        let before = engine.fen()
        // Backwards, two squares from the seventh rank, unreachable, no promotion piece, not a square, a letter on a
        // move that does not promote, empty, an unknown piece, a king promotion, a letter too many
        for move in ["b7b6", "b7b5", "e1e3", "b7b8", "zz99", "e1e2q", "", "b7b8k", "b7b8x", "b7b8qq"] {
            #expect(!engine.move(uci: move), "\(move)")
            #expect(engine.fen() == before, "\(move)")
        }
    }
}
