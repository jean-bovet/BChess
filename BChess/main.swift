//
//  main.swift
//  BChess
//
//  Created by Jean Bovet on 11/9/17.
//  Copyright © 2017 Jean Bovet. All rights reserved.
//

import Foundation
import os.log

extension Analysis.Info {

    var uciInfoMessage: String {
        return "info depth \(depth) time \(time) nodes \(nodeEvaluated) nps \(movesPerSecond) score cp \(evaluation.value) pv \(evaluation.lineInfo)"
    }
    
    var uciBestMove: String {
        return "bestmove \(evaluation.move)"
    }
}

class UCI {
    
    let log: OSLog
    let minimax = Analysis()
    
    var async = true
    
    var xcodeMode = false
    
    var board = Board()
    
    init() {
        log = OSLog(subsystem: "ch.arizona-software.BChess", category: "uci")

        // Disable output buffering otherwise the GUI won't receive any command
        setbuf(__stdoutp, nil)
        
        // Initialize by default with the empty board
        board = StartPosFEN.board()!
    }
    
    func read() -> String? {
        return readLine(strippingNewline: true)
    }
    
    func write(_ what: String) {
        print(what)
    }
    
    func generateMoves(fen: String) {
        let parser = FENParser(fen: fen)
        if let board = parser.parse() {
            let generator = MoveGenerator(board: board, color: .white)
            let moves = generator.generateMoves()
            
            for move in moves {
                let newBoard = board.move(move: move)
                print("\(newBoard)\n")
            }
        }
    }
    
    func evaluate(board: Board, depth: Int) {
        if xcodeMode {
            print(board)
        }
        
        minimax.analyzing = false
        let evaluateBlock = {
            let info = self.minimax.searchBestMove(board: board, color: .white, maxDepth: depth) { info in
                // info depth 2 score cp 214 time 1242 nodes 2124 nps 34928 pv e2e4 e7e5 g1f3
                // info depth 5 seldepth 29 time 5 nodes 13401 nps 2543 score cp -1 pv b1a3 a7b6 a2a4 a8a4
                let message = info.uciInfoMessage
                print(message)
                if !self.xcodeMode {
                    os_log("Info: %{public}@", log: self.log, message)
                }
            }
            
            // bestmove g1f3
            let message = info.uciBestMove
            print(message)
            if !self.xcodeMode {
                os_log("Done: %{public}@", log: self.log, message)
            }
        }
        
        if async {
            DispatchQueue.global(qos: .userInitiated).async(execute: evaluateBlock)
        } else {
            evaluateBlock()
        }
    }

    func processCmdPosition(_ tokens: inout [String]) {
        // position startpos moves e2e4
        // position fen 8/8/8/1q1k4/8/2P5/1N6/4K3 w - - 0 1 moves c3c4
        // position fen 8/8/8/1q1k4/8/2P5/1N6/4K3 w - - 0 1
        let cmd = tokens.removeFirst()
        
        if cmd == "startpos" {
            board = StartPosFEN.board()!
        } else if cmd == "fen" {
            let fen = tokens[0...5].joined(separator: " ")
            board = fen.board()!
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
            board = board.move(move: move)
        }
        tokens.removeAll()
    }
    
    func processCmdGo(_ tokens: inout [String]) {
        // go infinite
        // go wtime 300000 btime 300000
        let cmd = tokens.removeFirst()
        
        if cmd == "infinite" {
            evaluate(board: board, depth: Int.max)
        } else {
            evaluate(board: board, depth: 3)
        }
    }
    
    func process(_ tokens: inout [String]) {
        let cmd = tokens.removeFirst()
        
        switch cmd {
        case "xcode":
            async = false
            
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
            minimax.analyzing = false
            
        default:
            if xcodeMode {
                write("Unknown command \(cmd)")
            } else {
                os_log("Unknown command: %{public}@", log: log, cmd)
            }
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

let uci = UCI()
uci.run()
