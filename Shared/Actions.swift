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

    func undoMove() {
        guard document.engine.canMove(to: .backward) else {
            return
        }

        withAnimation {
            document.selection = Selection.empty()
            document.lastMove = nil

            if engine.isAnalyzing() {
                engine.cancel()
            }
            document.engine.move(to: .backward, variation: 0)
            document.pgn = document.engine.pgnAllGames()
        }
    }

    func redoMove() {
        guard document.engine.canMove(to: .forward) else {
            return
        }
        
        withAnimation {
            document.selection = Selection.empty()
            document.lastMove = nil

            document.engine.move(to: .forward, variation: 0)
            document.pgn = document.engine.pgnAllGames()
        }
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
            
            if document.variations.show {
                // If the variations are being show, then move using the selected variation index
                engine.move(to: to, variation: UInt(document.variations.selectedVariationIndex))
                document.pgn = document.engine.pgnAllGames()
                
                // Hide the variations
                document.variations.show = false
            } else {
                // Get the next move UUID
                let nextMoveUUID = UInt(engine.moveUUID(to))
                if document.game.hasVariations(moveUUID: nextMoveUUID) {
                    // If that move has variations - that is, more than one move possible,
                    // the show these variations to the user who can select one of them.
                    document.variations.show = true
                    document.variations.variations = document.game.variations(moveUUID: nextMoveUUID)
                } else {
                    // That move has no variations
                    document.variations.show = false
                    engine.move(to: to, variation: 0)
                    document.pgn = document.engine.pgnAllGames()
                }
            }
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
        UIPasteboard.general.string = engine.getPGNCurrentGame()
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
