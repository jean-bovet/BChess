//
//  main.swift
//  BChess
//
//  Created by Jean Bovet on 11/9/17.
//  Copyright © 2017 Jean Bovet. All rights reserved.
//

import Foundation
import os.log

// Disable output buffering otherwise the GUI won't receive any command
setbuf(__stdoutp, nil)

func read() -> String? {
    return readLine(strippingNewline: true)
}

func write(_ what: String) {
    print(what)
}

func generateMoves(fen: String) {
    let parser = FENParser(fen: fen)
    if let board = parser.parse() {
        let generator = MoveGenerator()
        let moves = generator.generateMoves(board: board, color: .white)
        
        for move in moves {
            let newBoard = board.move(from: move.from, to: move.to)
            print("\(newBoard)\n")
        }
    }
}

func evaluate(fen: String) {
    let parser = FENParser(fen: fen)
    if let board = parser.parse() {
        let minimax = Minimax()
        let eval = minimax.evaluatePosition(board: board, color: .white)
        let move = minimax.bestMove(board: board, color: .white)
        print("Eval is \(eval) for current position. Best move is \(move)")
    }
}

let log = OSLog(subsystem: "ch.arizona-software.BChess", category: "uci")

if CommandLine.arguments.count > 1 {
    let arg = CommandLine.arguments[1]
    if arg.hasPrefix("fen=") {
//        generateMoves(fen: String(arg.dropFirst(4)))
//        generateMoves(fen: "8/8/8/1p3P2/8/3B4/8/8 w - - 0 1")
//        generateMoves(fen: "8/8/8/3P4/8/1p1R4/8/8 w - - 0 1")
//        generateMoves(fen: "8/8/8/8/4K3/8/8/8 w - - 0 1")
//        generateMoves(fen: "8/8/8/3P4/8/4N3/8/8 w - - 0 1")
        
        evaluate(fen: "8/8/8/3k4/1q6/2P5/8/4K3 w - - 0 1")
//        let parser = FENParser(fen: "8/8/8/1q1k4/8/2P5/2N5/4K3 w - - 0 1")
        exit(0)
    }
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
            break
        case "stop":
            break
        default:
            write("Unknown command \(line)")
        }
    }
}
