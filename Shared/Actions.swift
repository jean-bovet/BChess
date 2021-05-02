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
        document.pgn = document.pgnBeforeAnalyzing
        document.engine.setPGN(document.pgn)
    }
        
    func changeBoardState(state: ChessDocument.State) {
        if document.state == .play {
            document.state = state
            document.pgnBeforeAnalyzing = document.pgn
        } else {
            document.state = .play
            analyzeReset()
        }
    }

    func newGame() {
        engine.setFEN(StartPosFEN)
        document.pgn = engine.pgn()
                
        document.selection = Selection.empty()
        document.lastMove = nil        
    }

    func undoMove() {
        guard engine.canUndoMove() else {
            return
        }

        withAnimation {
            document.selection = Selection.empty()
            document.lastMove = nil

            if engine.isAnalyzing() {
                engine.cancel()
            }
            engine.undoMove()
            document.pgn = document.engine.pgn()
        }
    }

    func redoMove() {
        guard engine.canRedoMove() else {
            return
        }
        
        withAnimation {
            document.selection = Selection.empty()
            document.lastMove = nil

            engine.redoMove()
            document.pgn = document.engine.pgn()
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
        pb.setString(engine.pgn(), forType: .string)
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
            document.pgn = document.engine.pgn()
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
            document.pgn = document.engine.pgn()
            return true
        } else {
            return false
        }
    }

}
