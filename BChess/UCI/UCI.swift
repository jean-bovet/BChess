//
//  UCI.swift
//  BChess
//
//  Created by Jean Bovet on 11/23/17.
//  Copyright © 2017 Jean Bovet. All rights reserved.
//

import Foundation
import os.log

/// What a `go` command asks for, and the time and depth the engine gets from it.
nonisolated struct SearchLimits: Equatable, Sendable {
    /// The longest any time value can be, in milliseconds: a day. Every value is clamped to it when parsed, so
    /// the arithmetic below cannot overflow, and the timer's nanoseconds cannot either.
    static let maximum = 86_400_000
    /// What the engine keeps for itself on every move, in milliseconds
    static let overhead = 50
    /// The shortest search time that is ever allotted, in milliseconds
    static let minimum = 10
    /// The moves left in the period when `go` does not say
    static let defaultMovesToGo = 30

    var wtime, btime, winc, binc, movestogo, movetime, depth: Int?   // ms / count / plies
    var infinite = false

    /// The tokens that follow `go`.
    init(goTokens tokens: [String]) {
        var index = 0
        func value(clamped range: ClosedRange<Int>) -> Int? {
            // The value is absent, and the next token left alone, when it is not an integer
            guard index + 1 < tokens.count, let number = Int(tokens[index + 1]) else {
                return nil
            }
            index += 1
            return min(max(number, range.lowerBound), range.upperBound)
        }
        let times = 0...Self.maximum
        while index < tokens.count {
            switch tokens[index] {
            case "wtime": wtime = value(clamped: times)
            case "btime": btime = value(clamped: times)
            case "winc": winc = value(clamped: times)
            case "binc": binc = value(clamped: times)
            case "movetime": movetime = value(clamped: times)
            case "movestogo":
                // Fewer than one move to go means nothing
                if let number = value(clamped: Int.min...1000), number >= 1 {
                    movestogo = number
                }
            case "depth":
                // At least 1, so that a move is always found; at most 64, which every conversion to the engine's int holds
                depth = value(clamped: 1...64)
            case "infinite": infinite = true
            default: break // nodes, searchmoves, ponder, mate and their arguments
            }
            index += 1
        }
    }

    /// What `FEngine.evaluate(_:time:)` takes: depth -1 is unlimited, and time 0 means no timer (seconds).
    func search(whiteToMove: Bool) -> (depth: Int, time: TimeInterval) {
        let searchDepth = depth ?? -1
        if infinite {
            return (searchDepth, 0)
        }
        if let movetime {
            return (searchDepth, Self.seconds(movetime - Self.overhead))
        }
        guard let remaining = whiteToMove ? wtime : btime else {
            return (searchDepth, 0)
        }
        let increment = (whiteToMove ? winc : binc) ?? 0
        let budget = remaining / (movestogo ?? Self.defaultMovesToGo) + increment
        return (searchDepth, Self.seconds(min(budget, remaining - Self.overhead)))
    }

    private static func seconds(_ milliseconds: Int) -> TimeInterval {
        TimeInterval(min(max(milliseconds, minimum), maximum)) / 1000
    }
}

class UCI {
    
    static let defaultDepth = 6

    let log: OSLog
    let engine = FEngine()

    var xcodeMode = false
    
    init() {        
        log = OSLog(subsystem: "ch.arizona-software.BChess", category: "uci")

        // Disable output buffering otherwise the GUI won't receive any command
        setbuf(__stdoutp, nil)
        
        // Initialize by default with the empty board
        engine.setFEN(StartPosFEN)
        
        // Make sure to use the opening book
        engine.useOpeningBook = true
    }
    
    func engineOutput(_ message: String) {
        Self.output(message, log: log, xcodeMode: xcodeMode)
    }

    // Static so that the search callback, which runs on another thread, does not capture the UCI object
    nonisolated static func output(_ message: String, log: OSLog, xcodeMode: Bool) {
        print(message)
        if !xcodeMode {
            os_log("%{public}@", log: log, message)
        }
    }
    
    func read() -> String? {
        return readLine(strippingNewline: true)
    }
    
    func processCmdPosition(_ tokens: inout [String]) {
        // position startpos moves e2e4
        // position fen 8/8/8/1q1k4/8/2P5/1N6/4K3 w - - 0 1 moves c3c4
        // position fen 8/8/8/1q1k4/8/2P5/1N6/4K3 w -
        guard !tokens.isEmpty else {
            os_log("position without arguments ignored", log: log)
            return
        }
        let cmd = tokens.removeFirst()
        
        // The FEN, if any, runs up to "moves" or the end of the line
        var moves: [String] = []
        if let index = tokens.firstIndex(of: "moves") {
            moves = Array(tokens[(index + 1)...])
            tokens.removeSubrange(index...)
        }
        
        switch cmd {
        case "startpos":
            engine.setFEN(StartPosFEN)
            
        case "fen":
            let fen = tokens.joined(separator: " ")
            if fen.isEmpty || !engine.setFEN(fen) {
                // All or nothing: no half-read position, and the moves belong to the position that was refused
                os_log("Invalid FEN \"%{public}@\": using the start position", log: log, fen)
                engine.setFEN(StartPosFEN)
                return
            }
            
        default:
            os_log("Unknown position %{public}@ ignored", log: log, cmd)
            return
        }
        
        processCmdMove(moves)
    }
    
    func processCmdMove(_ moves: [String]) {
        for moveToken in moves {
            // http://wbec-ridderkerk.nl/html/UCIProtocol.html
            // Examples:  e2e4, e7e5, e1g1 (white short castling), e7e8q (for promotion)
            if !engine.move(uci: moveToken) {
                os_log("Illegal move %{public}@: the rest of the moves is ignored", log: log, moveToken)
                break
            }
        }
    }

    func processCmdGo(_ tokens: inout [String]) {
        // go infinite
        // go wtime 300000 btime 300000 winc 1000 binc 1000
        // go movetime 500
        // go depth 6
        let limits = SearchLimits(goTokens: tokens)
        let (depth, time) = limits.search(whiteToMove: engine.isWhite())
        
        let log = self.log
        let xcodeMode = self.xcodeMode
        engine.evaluate(depth, time: time) { (info, completed) in
            if completed {
                // The totals of the whole search, then the move
                if info.hasBestMove {
                    UCI.output(info.uciInfoMessage, log: log, xcodeMode: xcodeMode)
                }
                UCI.output(info.uciBestMove, log: log, xcodeMode: xcodeMode)
            } else {
                UCI.output(info.uciInfoMessage, log: log, xcodeMode: xcodeMode)
            }
        }
    }
    
    func process(_ tokens: inout [String]) {
        guard !tokens.isEmpty else {
            return
        }
        let cmd = tokens.removeFirst()
        
        switch cmd {
        case "uci":
            engineOutput("id name BChess")
            engineOutput("id author Jean Bovet")
            engineOutput("uciok")
            
        case "xcode":
            xcodeMode = true
            engine.async = false
            
        case "quit":
            exit(0)
            
        case "isready":
            engineOutput("readyok")
            
        case "ucinewgame":
            engine.setFEN(StartPosFEN)
            
        case "position":
            processCmdPosition(&tokens)
            
        case "go":
            processCmdGo(&tokens)
            
        case "stop":
            engine.stop()
            
        default:
            // Nothing but UCI lines goes to stdout: setoption, debug, register, ponderhit and anything
            // unknown are ignored
            os_log("Ignored command %{public}@", log: log, cmd)
        }
    }
    
    func run() {
        if CommandLine.arguments.count > 1 {
            let arguments = CommandLine.arguments[1...].map { String($0) }
            for tokens in arguments.split(separator: "||") {
                var t = tokens.map { String($0) }
                process(&t)
            }
            exit(0)
        }
        
        while let line = read() {
            os_log("Received: %{public}@", log: log, line)
            
            var tokens = line.split(whereSeparator: \.isWhitespace).map { String($0) }
            process(&tokens)
        }
    }
}
