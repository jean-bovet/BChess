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
}

class UCI {
    
    let log: OSLog
    let minimax = Analysis()
    
    init() {
        log = OSLog(subsystem: "ch.arizona-software.BChess", category: "uci")

        // Disable output buffering otherwise the GUI won't receive any command
        setbuf(__stdoutp, nil)
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
            let moves = MoveGenerator.generateMoves(board: board, color: .white)
            
            for move in moves {
                let newBoard = board.move(move: move)
                print("\(newBoard)\n")
            }
        }
    }
    
    func evaluate(fen: String, depth: Int) {
        let parser = FENParser(fen: fen)
        if let board = parser.parse() {
            minimax.analyze = false
            DispatchQueue.global(qos: .userInitiated).async { // 1
                let info = self.minimax.searchBestMove(board: board, color: .white, maxDepth: depth) { info in
                    // info depth 2 score cp 214 time 1242 nodes 2124 nps 34928 pv e2e4 e7e5 g1f3
                    // info depth 5 seldepth 29 time 5 nodes 13401 nps 2543 score cp -1 pv b1a3 a7b6 a2a4 a8a4
                    let message = info.uciInfoMessage
                    print(message)
                    os_log("Info: %{public}@", log: self.log, message)
                }
                
                let message = info.uciInfoMessage
                print(message)
                os_log("Done: %{public}@", log: self.log, message)
            }
            
            //        print(board)
            //
            //        var lineBoard = board
            //        for move in evaluation.line {
            //            lineBoard = lineBoard.move(move: move)
            //            print(lineBoard)
            //        }
            
//            print("* Best move is \(evaluation.move) with \(evaluation.line) and \(minimax.evaluateCount) moves evaluated.")
        }
    }

    func run() {
        if CommandLine.arguments.count > 1 {
            let arg = CommandLine.arguments[1]
            if arg.hasPrefix("fen=") {
                evaluate(fen: "8/8/8/1q1k4/8/2P5/1N6/4K3 w - - 0 1", depth: 7)
            } else if arg == "go infinite" {
                evaluate(fen: StartPosFEN, depth: Int.max)
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
                
                switch line {
                case "quit":
                    exit(0)
                    break
                case "isready":
                    write("readyok")
                    break
                case "position startpos":
                    break
                case "go infinite":
                    evaluate(fen: StartPosFEN, depth: Int.max)
                    break
                case "stop":
                    minimax.analyze = false
                    break
                default:
                    write("Unknown command \(line)")
                }
            }
        }
    }
}

let uci = UCI()
uci.run()
