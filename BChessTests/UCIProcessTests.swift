//
//  UCIProcessTests.swift
//  BChessTests
//
//  Drives the built BChessUCI tool through pipes, the way a GUI does.
//

import Foundation
import Testing

/// A running BChessUCI process with its output collected on a background queue.
private final class UCIProcess: @unchecked Sendable {
    private let process = Process()
    private let input = Pipe()
    private let output = Pipe()
    private let lines = Locked<[String]>([])
    private let partial = Locked(Data())

    init() throws {
        // The tool is a build dependency, built next to the test bundle
        let tool = Bundle(for: UCIProcess.self).bundleURL.deletingLastPathComponent().appendingPathComponent("BChessUCI")
        process.executableURL = tool
        process.standardInput = input
        process.standardOutput = output
        process.standardError = FileHandle.nullDevice
        output.fileHandleForReading.readabilityHandler = { [weak self] handle in
            self?.collect(handle.availableData)
        }
        try process.run()
    }

    private func collect(_ data: Data) {
        partial.update { buffer in
            buffer.append(data)
            while let newline = buffer.firstIndex(of: 0x0A) {
                let line = String(decoding: buffer[buffer.startIndex..<newline], as: UTF8.self)
                lines.update { $0.append(line) }
                buffer.removeSubrange(buffer.startIndex...newline)
            }
        }
    }

    func send(_ command: String) {
        input.fileHandleForWriting.write(Data((command + "\n").utf8))
    }

    /// The first line, after `after` lines have been consumed, that matches; nil on timeout.
    func waitForLine(after start: Int = 0, timeout: TimeInterval = 5, where match: (String) -> Bool) -> String? {
        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            if let line = lines.value.dropFirst(start).first(where: match) {
                return line
            }
            Thread.sleep(forTimeInterval: 0.02)
        }
        return nil
    }

    var lineCount: Int { lines.value.count }

    var allLines: [String] { lines.value }

    func terminate() {
        output.fileHandleForReading.readabilityHandler = nil
        if process.isRunning {
            process.terminate()
        }
    }

    func waitForExit(timeout: TimeInterval = 5) -> Bool {
        let deadline = Date().addingTimeInterval(timeout)
        while process.isRunning && Date() < deadline {
            Thread.sleep(forTimeInterval: 0.02)
        }
        return !process.isRunning
    }
}

struct UCIProcessTests {

    private static let first = "r1bqkbnr/pppp1ppp/2n5/4p3/4P3/5N2/PPPP1PPP/RNBQKB1R w KQkq - 2 3"
    private static let second = "rnbqkb1r/pppp1ppp/5n2/4p3/2B1P3/5N2/PPPP1PPP/RNBQK2R b KQkq - 3 3"

    private func isLegalMove(_ move: String, in fen: String) -> Bool {
        let engine = FEngine()
        engine.setFEN(fen)
        return engine.move(uci: move)
    }

    @Test func goInfiniteThenStopPrintsBestMove() throws {
        let uci = try UCIProcess()
        defer { uci.terminate() }

        // The position is outside the opening book, which would answer without a search
        uci.send("uci")
        uci.send("position fen \(Self.first)")
        uci.send("go infinite")
        uci.send("stop")

        let best = uci.waitForLine { $0.hasPrefix("bestmove") }
        let move = try #require(best).dropFirst("bestmove ".count)
        #expect(move != "??")
        #expect(isLegalMove(String(move), in: Self.first))

        // stdin stays responsive
        let mark = uci.lineCount
        uci.send("isready")
        #expect(uci.waitForLine(after: mark) { $0 == "readyok" } != nil)

        // A second search in another position
        let secondMark = uci.lineCount
        uci.send("position fen \(Self.second)")
        uci.send("go infinite")
        // stdin is answered while the search runs, not only after it
        uci.send("isready")
        #expect(uci.waitForLine(after: secondMark) { $0 == "readyok" } != nil)
        uci.send("stop")
        let secondBest = try #require(uci.waitForLine(after: secondMark) { $0.hasPrefix("bestmove") })
        #expect(isLegalMove(String(secondBest.dropFirst("bestmove ".count)), in: Self.second))

        uci.send("quit")
        #expect(uci.waitForExit())
    }

    // Black has no legal move (stalemate): UCI's null move
    @Test func positionWithoutMovesPrintsTheNullMove() throws {
        let uci = try UCIProcess()
        defer { uci.terminate() }

        uci.send("uci")
        uci.send("position fen 7k/5Q2/6K1/8/8/8/8/8 b - - 0 1")
        uci.send("go infinite")
        uci.send("stop")

        let best = try #require(uci.waitForLine { $0.hasPrefix("bestmove") })
        #expect(best == "bestmove 0000")
        uci.send("quit")
        #expect(uci.waitForExit())
    }

    private static let mateInOne = "6k1/5ppp/8/8/8/8/8/R5K1 w - - 0 1"
    private static let start = "rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1"

    /// Searches from `position` until an info line satisfies `enough`, then stops. Returns the lines printed since `go`.
    private func search(_ uci: UCIProcess, position: String, until enough: (String) -> Bool = { $0.hasPrefix("info depth 2 ") }) throws -> [String] {
        uci.send("position \(position)")
        let mark = uci.lineCount
        uci.send("go infinite")
        #expect(uci.waitForLine(after: mark, timeout: 20, where: enough) != nil)
        uci.send("stop")
        #expect(uci.waitForLine(after: mark) { $0.hasPrefix("bestmove") } != nil)
        return Array(uci.allLines.dropFirst(mark))
    }

    private func bestMove(in lines: [String]) -> String {
        lines.last(where: { $0.hasPrefix("bestmove") })?.dropFirst("bestmove ".count).description ?? ""
    }

    @Test func promotionInPositionMoves() throws {
        let uci = try UCIProcess()
        defer { uci.terminate() }

        let lines = try search(uci, position: "fen 8/1P6/8/8/8/8/8/k3K3 w - - 0 1 moves b7b8q")
        #expect(isLegalMove(bestMove(in: lines), in: "1Q6/8/8/8/8/8/8/k3K3 b - - 0 1"))
    }

    @Test func unsafeAndLegacyFENs() throws {
        let uci = try UCIProcess()
        defer { uci.terminate() }

        // An unknown piece letter: refused, the process stays alive and plays from the start position
        uci.send("position fen 4k3/8/8/8/8/8/8/4K2X w - - 0 1 moves e1e2")
        let mark = uci.lineCount
        uci.send("isready")
        #expect(uci.waitForLine(after: mark) { $0 == "readyok" } != nil)
        var lines = try search(uci, position: "fen 4k3/8/8/8/8/8/8/4K2X w - - 0 1 moves e1e2")
        #expect(isLegalMove(bestMove(in: lines), in: Self.start))

        // An en passant square that cannot exist: sanitized, so the move is played
        lines = try search(uci, position: "fen 4k3/8/8/8/8/8/8/4K3 w - z9 0 1 moves e1e2")
        #expect(isLegalMove(bestMove(in: lines), in: "4k3/8/8/8/8/8/4K3/8 b - - 1 1"))
    }

    @Test func promotionInBestMoveAndPV() throws {
        let uci = try UCIProcess()
        defer { uci.terminate() }

        let lines = try search(uci, position: "fen 8/1P6/8/8/8/8/8/k3K3 w - - 0 1", until: { $0.hasPrefix("info depth 3 ") })
        #expect(lines.contains { $0.hasPrefix("info ") && $0.contains(" pv b7b8q") })
        #expect(bestMove(in: lines) == "b7b8q")
    }

    @Test func finalInfoBeforeBestMove() throws {
        let uci = try UCIProcess()
        defer { uci.terminate() }

        // The budget runs out inside a depth: no timing of ours is involved
        uci.send("position fen \(Self.first)")
        let mark = uci.lineCount
        uci.send("go movetime 400")
        #expect(uci.waitForLine(after: mark) { $0.hasPrefix("bestmove") } != nil)

        let lines = Array(uci.allLines.dropFirst(mark))
        let infos = lines.filter { $0.hasPrefix("info ") }
        #expect(infos.count >= 2)
        #expect(lines.last?.hasPrefix("bestmove") == true)
        // The last line before bestmove is the final one
        #expect(lines[lines.count - 2] == infos.last)
        let final = infos[infos.count - 1]
        let before = infos[infos.count - 2]
        // Same completed depth, score and line, with the work of the interrupted depth added
        #expect(field("depth", in: final) == field("depth", in: before))
        #expect(text(after: "score", until: "time", in: final) == text(after: "score", until: "time", in: before))
        #expect(text(after: "pv", until: nil, in: final) == text(after: "pv", until: nil, in: before))
        #expect(field("nodes", in: final) > field("nodes", in: before))
        #expect(field("time", in: final) >= field("time", in: before))
    }

    /// The tokens between two keywords of an info line, as one string.
    private func text(after start: String, until end: String?, in line: String) -> String {
        let tokens = line.split(separator: " ").map(String.init)
        guard let from = tokens.firstIndex(of: start) else { return "" }
        let to = end.flatMap { tokens.firstIndex(of: $0) } ?? tokens.count
        return tokens[(from + 1)..<to].joined(separator: " ")
    }

    private func field(_ name: String, in line: String) -> Int {
        let tokens = line.split(separator: " ")
        guard let index = tokens.firstIndex(of: Substring(name)), index + 1 < tokens.count else { return -1 }
        return Int(tokens[index + 1]) ?? -1
    }

    @Test func onlyUCILinesOnStdout() throws {
        let uci = try UCIProcess()
        defer { uci.terminate() }

        for command in ["uci", "", "setoption name Hash value 16", "foo", "position", "isready", "position fen \(Self.first)", "ucinewgame"] {
            uci.send(command)
        }
        let mark = uci.lineCount
        uci.send("go infinite")
        #expect(uci.waitForLine(after: mark, timeout: 20) { $0.hasPrefix("info ") } != nil)
        uci.send("stop")
        let best = try #require(uci.waitForLine(after: mark) { $0.hasPrefix("bestmove") })

        let pattern = /^(id |uciok$|readyok$|info |bestmove )/
        for line in uci.allLines {
            #expect(line.firstMatch(of: pattern) != nil, "\(line)")
        }
        #expect(uci.allLines.contains("uciok"))
        #expect(uci.allLines.contains("readyok"))
        // ucinewgame without a position after it: the start position
        #expect(isLegalMove(String(best.dropFirst("bestmove ".count)), in: Self.start))
    }

    @Test func scoreIsFromTheEngineSide() throws {
        let uci = try UCIProcess()
        defer { uci.terminate() }

        // A queen up for the side to move, White then Black
        for position in ["fen rnb1kbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1",
                         "fen rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNB1KBNR b KQkq - 0 1"] {
            let lines = try search(uci, position: position, until: { $0.hasPrefix("info depth 2 ") })
            let info = try #require(lines.first { $0.hasPrefix("info depth 2 ") })
            #expect(field("cp", in: info) > 0, "\(position)")
        }

        // Black has a mate in 1
        let lines = try search(uci, position: "fen 8/6k1/p7/2rbp3/8/7P/5qPK/8 b - - 3 39", until: { $0.hasPrefix("info depth 2 ") })
        #expect(lines.contains { $0.contains(" score mate 1 ") })
    }

    @Test func mateIsReportedAsMate() throws {
        let uci = try UCIProcess()
        defer { uci.terminate() }

        let lines = try search(uci, position: "fen \(Self.mateInOne)", until: { $0.hasPrefix("info depth 3 ") })
        #expect(lines.contains { $0.hasPrefix("info ") && $0.contains(" score mate 1 ") })
        #expect(bestMove(in: lines) == "a1a8")
    }

    // MARK: Time management

    @Test func clockIsHonoured() throws {
        let uci = try UCIProcess()
        defer { uci.terminate() }

        uci.send("position fen \(Self.first)")
        let mark = uci.lineCount
        let started = Date()
        uci.send("go wtime 3000 btime 3000")
        let best = try #require(uci.waitForLine(after: mark, timeout: 5) { $0.hasPrefix("bestmove") })
        #expect(Date().timeIntervalSince(started) < 1.0)
        #expect(isLegalMove(String(best.dropFirst("bestmove ".count)), in: Self.first))
    }

    @Test func movetimeIsHonoured() throws {
        let uci = try UCIProcess()
        defer { uci.terminate() }

        uci.send("position fen \(Self.first)")
        let mark = uci.lineCount
        let started = Date()
        uci.send("go movetime 300")
        let best = try #require(uci.waitForLine(after: mark, timeout: 5) { $0.hasPrefix("bestmove") })
        #expect(Date().timeIntervalSince(started) < 1.5)
        #expect(isLegalMove(String(best.dropFirst("bestmove ".count)), in: Self.first))
    }

    @Test func depthEndsTheSearch() throws {
        let uci = try UCIProcess()
        defer { uci.terminate() }

        uci.send("position fen \(Self.first)")
        let mark = uci.lineCount
        uci.send("go depth 2")
        let best = try #require(uci.waitForLine(after: mark, timeout: 5) { $0.hasPrefix("bestmove") })
        #expect(isLegalMove(String(best.dropFirst("bestmove ".count)), in: Self.first))
        let lines = Array(uci.allLines.dropFirst(mark))
        let lastInfo = try #require(lines.last { $0.hasPrefix("info ") })
        #expect(lastInfo.hasPrefix("info depth 2 "))
        #expect(!lines.contains { $0.hasPrefix("info depth 3 ") })
    }

    @Test func bareGoDoesNotCrash() throws {
        let uci = try UCIProcess()
        defer { uci.terminate() }

        uci.send("position fen \(Self.first)")
        let mark = uci.lineCount
        uci.send("go")
        #expect(uci.waitForLine(after: mark, timeout: 20) { $0.hasPrefix("info ") } != nil)
        uci.send("stop")
        #expect(uci.waitForLine(after: mark) { $0.hasPrefix("bestmove") } != nil)
    }
}
