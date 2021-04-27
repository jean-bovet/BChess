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
        document.analyzing.toggle()
        if document.analyzing {
            document.savedPGN = document.pgn
        } else {
            document.selection = Selection.empty()
            document.pgn = document.savedPGN
            document.engine.setPGN(document.pgn)
        }
    }
    
    func newGame() {
        engine.setFEN(StartPosFEN)
                
        document.selection = Selection.empty()
        document.lastMove = nil        
    }

    func undoMove() {
        withAnimation {
            document.selection = Selection.empty()
            document.lastMove = nil

            if engine.isAnalyzing() {
                engine.cancel()
            }
            if engine.canUndoMove() {
                engine.undoMove()
            }
            
            document.pgn = document.engine.pgn()
        }
    }

    func redoMove() {
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
