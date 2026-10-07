//
//  VariationChoicesTests.swift
//  BChessTests
//
//  What the variation picker shows for each move that can follow a position.
//

import Testing

@MainActor
struct VariationChoicesTests {

    private func choices(pgn: String, forwardMoves: Int) -> [Variation] {
        let session = GameSession(state: GameState(pgn: pgn, white: .human, black: .human))
        session.move(to: .start)
        for _ in 0..<forwardMoves {
            session.move(to: .forward)
        }
        return session.variations.choices
    }

    @Test func labelsComeFromTheMoves() {
        let result = choices(pgn: "1. e4 e5 (1... c5) 2. Nf3 Nc6 *", forwardMoves: 2)
        #expect(result.map(\.label) == ["1\u{2026}e5", "1\u{2026}c5"])
        #expect(result.map(\.index) == [0, 1])
        #expect(result.map(\.isMainLine) == [true, false])
    }

    @Test func whiteMovesAreNumberedWithADot() {
        let result = choices(pgn: "1. e4 e5 2. Nf3 (2. Nc3) 2... Nc6 *", forwardMoves: 3)
        #expect(result.map(\.label) == ["2. Nf3", "2. Nc3"])
    }

    @Test func squaresComeFromTheMoves() {
        let result = choices(pgn: "1. e4 e5 (1... c5) 2. Nf3 *", forwardMoves: 2)
        #expect(result[1].from.rank == 6 && result[1].from.file == 2)
        #expect(result[1].to.rank == 4 && result[1].to.file == 2)
    }

    @Test func nothingToChooseWhenTheMovesAreNotOffered() {
        let session = GameSession(state: GameState(pgn: "1. e4 e5 *", white: .human, black: .human))
        #expect(session.variations.choices.isEmpty)
    }

    private func fen(after moves: [String]) -> String {
        let engine = FEngine()
        for move in moves {
            #expect(engine.move(uci: move))
        }
        return engine.fen()
    }

    private func sessionAtTheBranch() -> GameSession {
        let session = GameSession(state: GameState(pgn: "1. e4 e5 (1... c5) 2. Nf3 *", white: .human, black: .human))
        session.move(to: .start)
        session.move(to: .forward)
        session.move(to: .forward)
        return session
    }

    @Test func choosingTheMainLineLandsOnItAndClosesThePicker() {
        let session = sessionAtTheBranch()
        #expect(session.variations.show)
        session.chooseVariation(0)
        #expect(!session.variations.show)
        #expect(session.fen == fen(after: ["e2e4", "e7e5"]))
    }

    @Test func choosingTheVariationLandsOnItAndClosesThePicker() {
        let session = sessionAtTheBranch()
        session.chooseVariation(1)
        #expect(!session.variations.show)
        #expect(session.fen == fen(after: ["e2e4", "c7c5"]))
    }
}
