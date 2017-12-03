//
//  UCI.swift
//  BChess
//
//  Created by Jean Bovet on 11/23/17.
//  Copyright © 2017 Jean Bovet. All rights reserved.
//

import Foundation
import os.log

extension Minimax.Info {
        
    var engineInfo: FEngineInfo {
        let info = FEngineInfo()
        info.depth = UInt(depth)
        info.time = UInt(time)
        info.value = evaluation.value
        info.nodeEvaluated = UInt(nodeEvaluated)
        info.movesPerSecond = UInt(movesPerSecond)

        var bestLine = [String]()
        for move in evaluation.line {
            bestLine.append(move.description)
        }
        info.bestLine = bestLine
        
        return info
    }
}

extension FEngineInfo {
    
    var uciInfoMessage: String {
        let lineInfo = bestLine.map { $0 }.joined(separator: " ")
        return "info depth \(depth) time \(time) nodes \(nodeEvaluated) nps \(movesPerSecond) score cp \(value) pv \(lineInfo)"
    }
    
    var uciBestMove: String {
        return "bestmove \(bestLine[0])"
    }
}

class UCI {
    
    let log: OSLog
    let engine: UCIEngine
    
    var xcodeMode = false
    
    init() {
        log = OSLog(subsystem: "ch.arizona-software.BChess", category: "uci")
        
//        engine = UCIEngineClassic()
        engine = UCIEngineFast()

        // Disable output buffering otherwise the GUI won't receive any command
        setbuf(__stdoutp, nil)
        
        // Initialize by default with the empty board
        engine.set(fen: StartPosFEN)
    }
    
    func engineOutput(_ message: String) {
        print(message)
        if !xcodeMode {
            os_log("%{public}@", log: self.log, message)
        }
    }
    
    func read() -> String? {
        return readLine(strippingNewline: true)
    }
    
    func write(_ what: String) {
        print(what)
    }
    
    func processCmdPosition(_ tokens: inout [String]) {
        // position startpos moves e2e4
        // position fen 8/8/8/1q1k4/8/2P5/1N6/4K3 w - - 0 1 moves c3c4
        // position fen 8/8/8/1q1k4/8/2P5/1N6/4K3 w - - 0 1
        let cmd = tokens.removeFirst()
        
        if cmd == "startpos" {
            engine.set(fen: StartPosFEN)
        } else if cmd == "fen" {
            let fen = tokens[0...5].joined(separator: " ")
            engine.set(fen: fen)
            tokens.removeFirst(6)
        }
        
        // Optional moves
        if tokens.first == "moves" {
            processCmdMove(&tokens)
        }
    }
    
    func processCmdMove(_ tokens: inout [String]) {
        assert(tokens.removeFirst() == "moves")
        for moveToken in tokens {
            assert(moveToken.count == 4)
            let start = moveToken.startIndex
            let middle = moveToken.index(start, offsetBy: 1)
            guard let from = String(moveToken[start...middle]).coordinate else {
                return
            }
            
            let secondToken = moveToken.index(start, offsetBy: 2)
            guard let to = String(moveToken[secondToken...]).coordinate else {
                return
            }
            let move = Move(from: from, to: to)
            engine.move(move: move)
        }
        tokens.removeAll()
    }
    
    func processCmdGo(_ tokens: inout [String]) {
        // go infinite
        // go wtime 300000 btime 300000
        let cmd = tokens.removeFirst()
        
        let depth = (cmd == "infinite") ? Int.max : UCIEngine.defaultDepth
        
        engine.evaluate(depth: depth) { (info, completed) in
            if completed {
                self.engineOutput(info.uciBestMove)
            } else {
                self.engineOutput(info.uciInfoMessage)
            }
        }
    }
    
    func process(_ tokens: inout [String]) {
        let cmd = tokens.removeFirst()
        
        switch cmd {
        case "xcode":
            xcodeMode = true
            engine.async = false
            
        case "quit":
            exit(0)
            
        case "isready":
            write("readyok")
            
        case "ucinewgame":
            // New game
            break
            
        case "position":
            processCmdPosition(&tokens)
            
        case "go":
            processCmdGo(&tokens)
            
        case "stop":
            engine.stop()
            
        default:
            engineOutput("Unknown command \(cmd)")
        }
    }
    
    func run() {
        // Performance testing
//        if true {
//            let arguments = ["xcode", "position fen 3r3k/6pp/8/6N1/2Q5/1B6/8/7K w - - 0 1", "go wtime 300000 btime 300000"]
//            for tokens in arguments {
//                var t = tokens.split(separator: " ").map { String($0) }
//                process(&t)
//            }
//            exit(0)
//        }
        
        if CommandLine.arguments.count > 1 {
            let arguments = CommandLine.arguments[1...].map { String($0) }
            for tokens in arguments.split(separator: "||") {
                var t = tokens.map { String($0) }
                process(&t)
            }
            exit(0)
        }
        
        if let line = read() {
            os_log("Bootstrapped with %{public}@", log: log, line)
            
            write("id name BChess")
            write("id author Jean Bovet")
            write("uciok")
            
            while let line = read() {
                os_log("Received: %{public}@", log: log, line)
                
                // position startpos
                // go infinite
                // stop
                
                var tokens = line.split(separator: " ").map { String($0) }
                process(&tokens)
            }
        }
    }
}
