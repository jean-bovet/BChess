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
}
