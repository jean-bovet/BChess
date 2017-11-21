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
    
    var xcodeMode = false
    
    var positionFen = StartPosFEN
    
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
    
    func evaluate(fen: String, depth: Int, async: Bool = true) {
        let parser = FENParser(fen: fen)
        if let board = parser.parse() {
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
                
                let message = info.uciInfoMessage
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
            var arg = CommandLine.arguments[1]
            xcodeMode = arg == "xcode=true"
            
            arg = CommandLine.arguments[2]
            if arg.hasPrefix("fen=") {
                // Best move is rook to check the black king: 4k3/8/8/8/8/8/2R5/4K3 w - - 0 1
                // Best move is the pawn to check both the queen and the king: 8/8/8/1q1k4/8/2P5/1N6/4K3 w - - 0 1
                evaluate(fen: "4k3/8/8/8/8/8/2R5/4K3 w - - 0 1", depth: 7, async: false)
            } else if arg == "go infinite" {
                evaluate(fen: StartPosFEN, depth: Int.max, async: false)
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
                    positionFen = StartPosFEN
                    break
                    
                case "go infinite":
                    evaluate(fen: positionFen, depth: Int.max)
                    break
                    
                case "stop":
                    minimax.analyzing = false
                    break
                    
                default:
                    let cmd = "position fen"
                    if line.hasPrefix(cmd){
                        // position fen 8/8/8/1q1k4/8/2P5/1N6/4K3 w - - 0 1
                        let fenIndex = line.index(line.startIndex, offsetBy: cmd.count)
                        let fen = line[fenIndex...]
                        positionFen = String(fen)
                    } else {
                        if xcodeMode {
                            write("Unknown command \(line)")
                        } else {
                            os_log("Unknown command: %{public}@", log: log, line)
                        }
                    }
                }
            }
        }
    }
}

let uci = UCI()
uci.run()
