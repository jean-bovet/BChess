//
//  Actions.swift
//  BChess
//
//  Created by Jean Bovet on 1/10/21.
//  Copyright © 2021 Jean Bovet. All rights reserved.
//

import SwiftUI

struct Actions {
    @Binding var document: BChessUIDocument
    
    var engine: FEngine {
        return document.engine
    }

    func newGame(playAgainstWhite: Bool) {
        engine.setFEN(StartPosFEN)
        if playAgainstWhite {
            document.playAgainst = .white
        } else {
            document.playAgainst = .black
        }
        if engine.isWhite() && document.playAgainst == .white {
            enginePlay()
        }
        if !engine.isWhite() && document.playAgainst == .black {
            enginePlay()
        }
        document.selection = Selection(position: Position.empty(), possibleMoves: [])
    }

    func playMove(move: FEngineMove) {
        document.selection = Selection(position: Position.empty(), possibleMoves: [])
        document.applyLevelSettings()
        document.engine.move(move.rawMoveValue)
        document.pgn = document.engine.pgn()
        document.lastMove = nil
    }
    
    func enginePlay() {
        engine.evaluate { (info, completed) in
            DispatchQueue.main.async {
                withAnimation {
                    if completed {
                        self.engine.move(info.bestMove)
                        
                        // TODO: refactor?
                        let move = FEngineMove()
                        move.fromFile = info.fromFile
                        move.fromRank = info.fromRank
                        move.toFile = info.toFile
                        move.toRank = info.toRank
                        move.rawMoveValue = info.bestMove
                        self.document.lastMove = move
                    }
                    self.document.info = info
                    self.document.pgn = self.engine.pgn()
                }
            }
        }
    }

}

