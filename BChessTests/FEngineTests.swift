//
//  FEngineTests.swift
//  BChessTests
//
//  Created by Jean Bovet on 5/10/21.
//  Copyright © 2021 Jean Bovet. All rights reserved.
//

import Testing

struct FEngineTests {

    /// Cut-offs from the table are always on (ENGINE-3 search step 7): the app has no switch any more
    @Test func tableCutOffsAreOnByDefault() {
        #expect(FEngine().ttEnabled)
    }

    /// The probes that validate a pasted text or a file cost no table, and a search allocates the size of
    /// the platform: 16 MB on a phone, 64 MB on a Mac.
    @Test func probeEngineAllocatesNoTable() {
        let engine = FEngine()
        engine.useOpeningBook = false
        #expect(engine.transpositionTableBytes() == 0)
        #expect(engine.setFEN("r1bqkbnr/pppp1ppp/2n5/4p3/4P3/5N2/PPPP1PPP/RNBQKB1R w KQkq - 2 3"))
        #expect(engine.setPGN("1. e4 e5 2. Nf3 *"))
        #expect(engine.transpositionTableBytes() == 0)

        engine.async = false
        engine.evaluate(2) { _, _ in }
        #expect(engine.transpositionTableBytes() == 64 * 1024 * 1024)
    }

    /// Below Maximum the opening book is not used: the lower levels open with their own randomness
    @Test func handicappedSearchSkipsTheBook() throws {
        let start = "rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1"
        func reply(_ strength: EngineStrength) throws -> FEngineInfo {
            let engine = FEngine()
            engine.async = false
            engine.useOpeningBook = true
            engine.strength = strength
            #expect(engine.loadOpening("1. e4 e5 2. Nf3 *"))
            #expect(engine.setFEN(start))
            let result = Locked<FEngineInfo?>(nil)
            engine.evaluate(2) { info, completed in
                if completed { result.value = info }
            }
            return try #require(result.value)
        }
        let beginner = try reply(.beginner)
        #expect(beginner.hasBestMove)
        #expect(beginner.nodeEvaluated > 0)
        // The book answers without a search
        let maximum = try reply(.maximum)
        #expect(maximum.hasBestMove)
        #expect(maximum.nodeEvaluated == 0)
    }

    @Test func strengthDefaultsToMaximum() {
        #expect(FEngine().strength == .maximum)
    }

    /// The iOS scheme runs UI tests only, so the phone size is checked through the function that chooses it
    @Test func hashSizePerPlatform() {
        #expect(FEngine.hashMegabytes(forPhone: true) == 16)
        #expect(FEngine.hashMegabytes(forPhone: false) == 64)
    }

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

    private func names(_ nodes: [FEngineMoveNode]) -> [String] {
        nodes.flatMap { [$0.name] + names($0.variations) }
    }

    @Test func treeNamesCarryChecksAndMates() {
        let check = FEngine()
        check.setPGN("1. e4 f6 2. Qh5+ g6 *")
        #expect(names(check.moveNodesTree()) == ["e4", "f6", "Qh5+", "g6"])

        let mate = FEngine()
        mate.setPGN("1. e4 e5 2. Bc4 Nc6 3. Qh5 Nf6 4. Qxf7# *")
        #expect(names(mate.moveNodesTree()) == ["e4", "e5", "Bc4", "Nc6", "Qh5", "Nf6", "Qxf7#"])
    }

    @Test func treeNamesDisambiguateKnights() {
        let engine = FEngine()
        engine.setPGN("1. d4 d5 2. Nf3 Nf6 3. Nc3 (3. Nbd2 e6 4. Nb3) 3... Nc6 4. Nd2 *")
        // The variation is named from the position it branches at, not from the main line
        #expect(Set(names(engine.moveNodesTree())) == ["d4", "d5", "Nf3", "Nf6", "Nc3", "Nbd2", "e6", "Nb3", "Nc6", "Nd2"])
    }

    @Test func treeNamesStartFromTheInitialFEN() {
        let engine = FEngine()
        #expect(engine.setFEN("4k3/8/8/8/8/5N2/8/1N2K3 w - - 0 1"))
        #expect(engine.move(uci: "b1d2"))
        #expect(engine.move(uci: "e8d8"))
        #expect(engine.move(uci: "f3d4"))
        #expect(names(engine.moveNodesTree()) == ["Nbd2", "Kd8", "Nd4"])
    }

    @Test func variationChoicesAreNamedFromTheCurrentPosition() {
        let engine = FEngine()
        engine.setPGN("1. d4 d5 2. Nf3 Nf6 3. Nbd2 (3. Nfd2) (3. Nc3) *")
        engine.move(to: .start, variation: 0)
        for _ in 0..<4 {
            engine.move(to: .forward, variation: 0)
        }
        #expect(engine.nextMoveChoices().map(\.name) == ["Nbd2", "Nfd2", "Nc3"])
    }
}
