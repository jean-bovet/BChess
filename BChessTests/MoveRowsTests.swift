//
//  MoveRowsTests.swift
//  BChessTests
//
//  How the game's move tree becomes rows, variation tokens and the strip of recent moves.
//

import Foundation
import Testing

private func rebuilt(pgn: String? = nil, fen: String? = nil, moves: [(String, String)] = []) -> (Game, FEngine) {
    let engine = FEngine()
    if let fen {
        engine.setFEN(fen)
    }
    if let pgn {
        engine.setPGN(pgn)
    }
    for (from, to) in moves {
        engine.move(from, to: to)
    }
    var game = Game()
    game.rebuild(engine: engine)
    return (game, engine)
}

/// Every node of the tree, main line and variations at any depth.
private func allNodes(_ nodes: [FEngineMoveNode]) -> [FEngineMoveNode] {
    nodes.flatMap { [$0] + allNodes($0.variations) }
}


struct MoveRowsTests {

    @Test func rowsPairWhiteAndBlack() throws {
        let (game, engine) = rebuilt(pgn: "1. e4 e5 2. Nf3 *")
        let tree = engine.moveNodesTree()
        #expect(game.rows.count == 2)
        #expect(game.rows[0].number == 1)
        #expect(game.rows[0].white?.uuid == tree[0].uuid)
        #expect(game.rows[0].black?.uuid == tree[1].uuid)
        #expect(game.rows[1].number == 2)
        #expect(game.rows[1].white?.name == "Nf3")
        #expect(game.rows[1].black == nil)
    }

    @Test func rowStartingWithBlack() {
        let (game, _) = rebuilt(fen: "rnbqkbnr/pppppppp/8/8/4P3/8/PPPP1PPP/RNBQKBNR b KQkq e3 0 1",
                                moves: [("e7", "e5"), ("g1", "f3")])
        #expect(game.rows.count == 2)
        #expect(game.rows[0].white == nil)
        #expect(game.rows[0].black?.name == "e5")
        #expect(game.rows[0].number == game.rows[0].black.map { Int($0.moveNumber) })
        #expect(game.rows[1].white?.name == "Nf3")
    }

    @Test func commentsAreKept() {
        let (game, _) = rebuilt(pgn: "1. e4 {King pawn} e5 {Open game} *")
        #expect(game.rows[0].whiteComment == "King pawn")
        #expect(game.rows[0].blackComment == "Open game")
    }

    @Test func variationsFlattenToTokens() {
        let (game, engine) = rebuilt(pgn: "1. e4 e5 (1... c5 2. Nf3 (2. c3)) 2. Nf3 *")
        let e5 = engine.moveNodesTree()[1]
        let c5 = e5.variations[0]
        let nf3 = c5.variations[0]
        let c3 = nf3.variations[0]
        #expect(game.rows[0].variations == [[
            .open,
            .move("1\u{2026}c5", uuid: c5.uuid),
            .move("2. Nf3", uuid: nf3.uuid),
            .open,
            .move("2. c3", uuid: c3.uuid),
            .close,
            .close,
        ]])
        #expect(game.rows[1].variations.isEmpty)
    }

    @Test func variationCommentsAreTokens() {
        let (game, engine) = rebuilt(pgn: "1. e4 e5 (1... c5 {Sicilian} 2. Nf3 (2. c3 {Alapin})) *")
        let c5 = engine.moveNodesTree()[1].variations[0]
        let nf3 = c5.variations[0]
        let c3 = nf3.variations[0]
        #expect(game.rows[0].variations == [[
            .open,
            .move("1\u{2026}c5", uuid: c5.uuid),
            .comment("Sicilian"),
            .move("2. Nf3", uuid: nf3.uuid),
            .open,
            .move("2. c3", uuid: c3.uuid),
            .comment("Alapin"),
            .close,
            .close,
        ]])
    }

    @Test func nodesHoldEveryUUID() {
        let (game, engine) = rebuilt(pgn: "1. e4 e5 (1... c5 2. Nf3 (2. c3)) 2. Nf3 (2. Nc3) *")
        let expected = Set(allNodes(engine.moveNodesTree()).map(\.uuid))
        #expect(expected.count == 7)
        #expect(Set(game.nodes.keys) == expected)
    }

    @Test func rowIndexCoversVariations() {
        let (game, engine) = rebuilt(pgn: "1. e4 e5 (1... c5 2. Nf3 (2. c3)) 2. Nf3 (2. Nc3) *")
        let tree = engine.moveNodesTree()
        let (e4, e5, nf3) = (tree[0], tree[1], tree[2])
        let c5 = e5.variations[0]
        let nf3InC5 = c5.variations[0]
        let c3 = nf3InC5.variations[0]
        let nc3 = nf3.variations[0]
        #expect(game.rowIndex[e4.uuid] == 0)
        #expect(game.rowIndex[e5.uuid] == 0)
        #expect(game.rowIndex[c5.uuid] == 0)
        #expect(game.rowIndex[nf3InC5.uuid] == 0)
        #expect(game.rowIndex[c3.uuid] == 0)
        #expect(game.rowIndex[nf3.uuid] == 1)
        #expect(game.rowIndex[nc3.uuid] == 1)
        #expect(game.rowIndex.count == 7)
    }

    @Test func variationCount() {
        #expect(rebuilt(pgn: "1. e4 e5 2. Nf3 *").0.variationCount == 0)
        #expect(rebuilt(pgn: "1. e4 e5 (1... c5 2. Nf3 (2. c3)) 2. Nf3 (2. Nc3) *").0.variationCount == 3)
    }

    @Test func pathOfAMainLineMove() {
        let (game, engine) = rebuilt(pgn: "1. e4 e5 2. Nf3 Nc6 *")
        let tree = engine.moveNodesTree()
        #expect(game.path(to: tree[2].uuid).map(\.name) == ["e4", "e5", "Nf3"])
        #expect(game.path(to: tree[0].uuid).map(\.name) == ["e4"])
        #expect(game.path(to: 987_654).isEmpty)
    }

    @Test func pathThroughAVariation() {
        let (game, engine) = rebuilt(pgn: "1. e4 e5 (1... c5 2. Nf3 d6 3. d4) *")
        let c5 = engine.moveNodesTree()[1].variations[0]
        let d4 = c5.variations[2]
        #expect(d4.name == "d4")
        #expect(game.path(to: d4.uuid).map(\.name) == ["e4", "c5", "Nf3", "d6", "d4"])
        #expect(game.path(to: c5.uuid).map(\.name) == ["e4", "c5"])
    }

    @Test func recentMovesAtTheStart() {
        let (game, engine) = rebuilt(pgn: "1. e4 e5 *")
        engine.move(to: .start, variation: 0)
        #expect(game.recentMoves(current: engine.currentMoveNodeUUID).isEmpty)
    }

    @Test func recentMovesInTheMiddleAndAtTheEnd() {
        let (game, engine) = rebuilt(pgn: "1. e4 e5 2. Nf3 Nc6 3. Bb5 a6 4. Ba4 Nf6 *")
        let tree = engine.moveNodesTree()
        let end = game.recentMoves(current: tree[7].uuid)
        #expect(end == [
            .move("2. Nf3", uuid: tree[2].uuid), .move("Nc6", uuid: tree[3].uuid),
            .move("3. Bb5", uuid: tree[4].uuid), .move("a6", uuid: tree[5].uuid),
            .move("4. Ba4", uuid: tree[6].uuid), .move("Nf6", uuid: tree[7].uuid),
        ])
        // Six plies ending on a White move start with a Black one
        let middle = game.recentMoves(current: tree[6].uuid)
        #expect(middle.first == .move("1\u{2026}e5", uuid: tree[1].uuid))
        #expect(middle.count == 6)
        #expect(game.recentMoves(current: tree[0].uuid) == [.move("1. e4", uuid: tree[0].uuid)])
    }

    @Test func recentMovesInAVariation() {
        let (game, engine) = rebuilt(pgn: "1. e4 e5 (1... c5 2. Nf3 d6 3. d4) 2. Nf3 *")
        let tree = engine.moveNodesTree()
        let c5 = tree[1].variations[0]
        let d4 = c5.variations[2]
        let tokens = game.recentMoves(current: d4.uuid)
        #expect(tokens.last == .move("3. d4", uuid: d4.uuid))
        #expect(tokens.count == 5)
        // The main-line move that follows 1. e4 is not part of the path
        #expect(!tokens.contains(.move("1\u{2026}e5", uuid: tree[1].uuid)))
        #expect(!tokens.contains(.move("e5", uuid: tree[1].uuid)))
    }
}
