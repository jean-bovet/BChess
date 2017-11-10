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

let log = OSLog(subsystem: "ch.arizona-software.BChess", category: "uci")

if CommandLine.arguments.count > 1 {
    let arg = CommandLine.arguments[1]
    if arg.hasPrefix("fen=") {
        let parser = FENParser(fen: String(arg.dropFirst(4)))
        if let board = parser.parse() {
            let analysis = Analysis()
            let boards = analysis.generateMoves(board: board, color: .white)
            
            for b in boards {
                print("\(b)\n")
            }
        }
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
