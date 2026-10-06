//
//  UCICommandTests.swift
//  BChessTests
//
//  The UCI tool's input handling, driven in-process through `UCI().process` (no subprocess).
//

import Testing

struct UCICommandTests {

    private let start = "rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1"
    private let middlegame = "r1bqkbnr/pppp1ppp/2n5/4p3/4P3/5N2/PPPP1PPP/RNBQKB1R w KQkq - 2 3"

    @discardableResult
    private func run(_ command: String, on uci: UCI) -> String {
        var tokens = command.split(whereSeparator: \.isWhitespace).map { String($0) }
        uci.process(&tokens)
        return uci.engine.fen()
    }

    @Test func barePositionLeavesThePositionAlone() {
        let uci = UCI()
        run("position fen \(middlegame)", on: uci)
        #expect(run("position", on: uci) == middlegame)
        #expect(run("position nonsense moves e2e4", on: uci) == middlegame)
    }

    @Test func positionFENWithoutAFENIsTheStartPosition() {
        let uci = UCI()
        run("position fen \(middlegame)", on: uci)
        #expect(run("position fen", on: uci) == start)
        run("position fen \(middlegame)", on: uci)
        #expect(run("position fen moves e2e4", on: uci) == start)
    }

    @Test func rejectedFENIsTheStartPositionAndItsMovesAreIgnored() {
        let uci = UCI()
        run("position fen \(middlegame)", on: uci)
        // An unknown piece letter
        #expect(run("position fen 4k3/8/8/8/8/8/8/4K2X w - - 0 1 moves e1e2", on: uci) == start)
        // A rank with 9 files
        run("position fen \(middlegame)", on: uci)
        #expect(run("position fen 4k4/8/8/8/8/8/8/4K3 w - - 0 1 moves e1e2", on: uci) == start)
    }

    @Test func shortFENsAreAccepted() {
        let uci = UCI()
        #expect(run("position fen 4k3/8/8/8/8/8/8/4K3 w -", on: uci) == "4k3/8/8/8/8/8/8/4K3 w - - 0 1")
        #expect(run("position fen 4k3/8/8/8/8/8/8/4K3 b", on: uci) == "4k3/8/8/8/8/8/8/4K3 b - - 0 1")
        // The moves follow a short FEN too
        #expect(run("position fen 4k3/8/8/8/8/8/8/4K3 w - moves e1e2", on: uci) == "4k3/8/8/8/8/8/4K3/8 b - - 1 1")
    }

    @Test func movesStopAtTheFirstIllegalOne() {
        let uci = UCI()
        #expect(run("position startpos moves e2e4 e7e9 d2d4", on: uci) == "rnbqkbnr/pppppppp/8/8/4P3/8/PPPP1PPP/RNBQKBNR b KQkq e3 0 1")
        #expect(run("position startpos moves e2e4 e7e5 zz", on: uci) == "rnbqkbnr/pppp1ppp/8/4p3/4P3/8/PPPP1PPP/RNBQKBNR w KQkq e6 0 2")
        // A promotion that is spelled in full
        #expect(run("position fen 8/1P6/8/8/8/8/8/k3K3 w - - 0 1 moves b7b8q", on: uci) == "1Q6/8/8/8/8/8/8/k3K3 b - - 0 1")
    }

    @Test func ucinewgameResetsThePosition() {
        let uci = UCI()
        run("position fen \(middlegame)", on: uci)
        #expect(run("ucinewgame", on: uci) == start)
    }

    @Test func blankAndUnknownCommandsAreIgnored() {
        let uci = UCI()
        run("position fen \(middlegame)", on: uci)
        for command in ["", "   ", "foo bar", "setoption name Hash value 16", "debug on", "register later", "ponderhit"] {
            #expect(run(command, on: uci) == middlegame, "\(command)")
        }
    }
}
