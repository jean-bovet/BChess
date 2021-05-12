//
//  Actions.swift
//  BChess
//
//  Created by Jean Bovet on 1/10/21.
//  Copyright © 2021 Jean Bovet. All rights reserved.
//

import SwiftUI

struct Actions {
    @Binding var document: ChessDocument
    
    var engine: FEngine {
        return document.engine
    }

    func rotateBoard() {
        document.rotated = !document.rotated
    }
    
    func analyze() {
        changeBoardState(state: .analyze)
    }
    
    func train() {
        changeBoardState(state: .train)
    }
    
    func analyzeReset() {
        document.selection = Selection.empty()
        document.lastMove = nil
        document.pgn = document.mode.pgnBeforeAnalyzing
        document.engine.setPGN(document.pgn)
    }
        
    func changeBoardState(state: GameMode.Value) {
        if document.mode.value == .play {
            document.mode.value = state
            document.mode.pgnBeforeAnalyzing = document.pgn
            if state == .train {
                engine.setFEN(StartPosFEN)
            }
        } else {
            document.mode.value = .play
            analyzeReset()
        }
    }

    func newGame() {
        engine.setFEN(StartPosFEN)
        document.info = nil
        document.pgn = engine.pgnAllGames()
                
        document.selection = Selection.empty()
        document.lastMove = nil        
    }

    func canMove(to: Direction) -> Bool {
        return engine.canMove(to: to);
    }
    
    func move(to: Direction) {
        guard engine.canMove(to: to) else {
            return
        }

        withAnimation {
            document.selection = Selection.empty()
            document.lastMove = nil

            if engine.isAnalyzing() {
                engine.cancel()
            }
            
            engine.move(to: to)
            document.pgn = document.engine.pgnAllGames()
        }
    }

    func pasteGame() {
        // Try to paste first as FEN format and if it fails,
        // try the PGN format
        if pasteFEN() {
            return
        } else {
            _ = pastePGN()
        }
    }
    
    func copyFEN() {
        #if os(macOS)
        let pb = NSPasteboard.general
        pb.declareTypes([.string], owner: nil)
        pb.setString(engine.fen(), forType: .string)
        #else
        UIPasteboard.general.string = engine.fen()
        #endif
    }

    func copyPGN() {
        #if os(macOS)
        let pb = NSPasteboard.general
        pb.declareTypes([.string], owner: nil)
        pb.setString(engine.getPGNCurrentGame(), forType: .string)
        #else
        UIPasteboard.general.string = engine.pgn()
        #endif
    }

    func pasteFEN() -> Bool {
        #if os(macOS)
        guard let content = NSPasteboard.general.string(forType: .string) else {
            return false
        }
        #else
        guard let content = UIPasteboard.general.string else {
            return false
        }
        #endif
        if engine.setFEN(content) {
            document.pgn = document.engine.pgnAllGames()
            return true
        } else {
            return false
        }
    }
    
    func pastePGN() -> Bool {
        #if os(macOS)
        guard let content = NSPasteboard.general.string(forType: .string) else {
            return false
        }
        #else
        guard let content = UIPasteboard.general.string else {
            return false
        }
        #endif
        if engine.setPGN(content) {
            document.pgn = document.engine.pgnAllGames()
            return true
        } else {
            return false
        }
    }

}
