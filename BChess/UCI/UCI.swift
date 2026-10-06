//
//  UCI.swift
//  BChess
//
//  Created by Jean Bovet on 11/23/17.
//  Copyright © 2017 Jean Bovet. All rights reserved.
//

import Foundation
import os.log

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
        // go wtime 300000 btime 300000
        let cmd = tokens.first
        
        // UCI only plays with time control
        let depth: Int
        let time: TimeInterval
        if cmd == "infinite" {
            depth = -1
            time = -1
        } else {
            // TODO time control
            depth = -1
            time = 10 // 10 seconds for now
        }
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
