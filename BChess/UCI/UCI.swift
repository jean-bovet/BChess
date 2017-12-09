//
//  UCI.swift
//  BChess
//
//  Created by Jean Bovet on 11/23/17.
//  Copyright © 2017 Jean Bovet. All rights reserved.
//

import Foundation
import os.log

// https://en.wikipedia.org/wiki/Forsyth–Edwards_Notation
let StartPosFEN = "rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1"

class UCI {
    
    let log: OSLog
    let engine = UCIEngine()
    
    var xcodeMode = false
    
    init() {        
        log = OSLog(subsystem: "ch.arizona-software.BChess", category: "uci")

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
            let from = String(moveToken[start...middle])
            
            let secondToken = moveToken.index(start, offsetBy: 2)
            let to = String(moveToken[secondToken...])
            engine.move(from: from, to: to)
        }
        tokens.removeAll()
    }
    
    func processCmdGo(_ tokens: inout [String]) {
        // go infinite
        // go wtime 300000 btime 300000
        let cmd = tokens.removeFirst()
        
        let depth = (cmd == "infinite") ? -1 : UCIEngine.defaultDepth
        
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
//            let arguments = ["xcode", "position fen 3r3k/6pp/8/6N1/2Q5/1B6/8/7K w - - 0 1", "go infinite"]
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
