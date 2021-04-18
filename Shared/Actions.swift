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
    
    func newGame(playAgainst: PlayAgainst) {
        engine.setFEN(StartPosFEN)
        document.playAgainst = playAgainst
        if engine.isWhite() && document.playAgainst == .white {
            enginePlay()
        }
        if !engine.isWhite() && document.playAgainst == .black {
            enginePlay()
        }
        document.selection = Selection(position: Position.empty(), possibleMoves: [])
        document.lastMove = nil
    }

    func playMove(move: FEngineMove) {
        document.selection = Selection(position: Position.empty(), possibleMoves: [])
        document.lastMove = nil
        document.applyLevelSettings()
        document.engine.move(move.rawMoveValue)
        document.pgn = document.engine.pgn()
    }
    
    func undoMove() {
        withAnimation {
            document.selection = Selection(position: Position.empty(), possibleMoves: [])
            document.lastMove = nil

            if document.playAgainst == .human {
                engine.undoMove()
            } else {
                if engine.isAnalyzing() {
                    engine.cancel()
                }
                engine.undoMove() // last human move
                if engine.canUndoMove() {
                    engine.undoMove() // last engine move
                }
            }
            document.pgn = document.engine.pgn()
        }
    }

    func redoMove() {
        withAnimation {
            document.selection = Selection(position: Position.empty(), possibleMoves: [])
            document.lastMove = nil

            engine.redoMove()
            document.pgn = document.engine.pgn()
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
    
    func pasteFEN() {
        #if os(macOS)
        guard let content = NSPasteboard.general.string(forType: .string) else {
            return
        }
        #else
        guard let content = UIPasteboard.general.string else {
            return
        }
        #endif
        engine.setFEN(content)
        document.pgn = document.engine.pgn()
    }
    
    func enginePlay() {
        guard engine.canPlay() else {
            return
        }
        
        guard document.playAgainst != .human else {
            return
        }
        
        engine.evaluate { (info, completed) in
            DispatchQueue.main.async {
                if completed {
                    withAnimation {
                        self.document.lastMove = info.bestEngineMove
                        self.document.info = info
                        
                        self.engine.move(info.bestMove)
                        self.document.pgn = self.engine.pgn()
                    }
                } else {
                    self.document.info = info
                }
            }
        }
    }

}

