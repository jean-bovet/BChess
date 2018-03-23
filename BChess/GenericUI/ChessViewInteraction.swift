//
//  ChessViewInteraction.swift
//  BChess
//
//  Created by Jean Bovet on 3/9/18.
//  Copyright © 2018 Jean Bovet. All rights reserved.
//

import Foundation
import CoreGraphics

typealias CompletionBlock = () -> ()
typealias AnimateStateBlock = (@escaping CompletionBlock) -> ()
typealias InfoChangedBlock = (FEngineInfo?) -> ()

class ChessViewInteraction {
    
    let view: ChessView
    let engine: FEngine

    let animateState: AnimateStateBlock

    let promotionPicker: ChessViewPromotionPicker
    
    var infoChanged: InfoChangedBlock? {
        didSet {
            infoChanged?(nil)
        }
    }
    
    var layouter: ChessViewLayouter {
        return view.layouter
    }
    
    var state: ChessViewState {
        return view.state!
    }
    
    enum PlayAgainst {
        case white
        case black
        case human
    }
    
    var playAgainstComputer : PlayAgainst = .black {
        didSet {
            playEngineIfPossible()
        }
    }
    
    init(view: ChessView, engine: FEngine, animateState: @escaping AnimateStateBlock) {
        self.view = view
        self.engine = engine
        self.animateState = animateState
        promotionPicker = ChessViewPromotionPicker(layouter: view.layouter, factory: view.piecesCache.factory, parent: view)
    }
    
    func handleTap(atLocation loc: CGPoint) {
        guard let (file, rank) = coordinate(location: loc) else {
            return
        }
        
        if !handleUserInitiatedMove(file: file, rank: rank) {
            showPossibleMoves(file: file, rank: rank)
        }
    }
    
    func handleUserInitiatedMove(file: UInt, rank: UInt) -> Bool {
        if let moves = state.possibleMoves {
            for move in moves {
                if move.toRank == rank && move.toFile == file {
                    if move.isPromotion {
                        promotionPicker.choose(isWhite: engine.isWhite(), callback: { (pieceName) in
                            if let pieceName = pieceName {
                                move.setPromotionPiece(pieceName)
                                self.doMove(move: move)
                            }
                        })
                    } else {
                        self.doMove(move: move)
                    }
                    return true
                }
            }
        }
        return false
    }
    
    func doMove(move: FEngineMove) {
        state.lastMove = nil
        state.possibleMoves = nil
        engine.move(move.rawMoveValue)
        animateState({
            self.enginePlay()
        })
    }
    
    func showPossibleMoves(file: UInt, rank: UInt) {
        let moves = engine.moves(at: UInt(rank), file: UInt(file))
        if moves.isEmpty {
            state.possibleMoves = nil
            animateState { }
        } else if let currentMoves = state.possibleMoves, currentMoves == moves {
            state.possibleMoves = nil
            animateState { }
        } else {
            state.possibleMoves = moves
            animateState({ })
        }
    }
    
    func coordinate(location: CGPoint) -> (UInt, UInt)? {
        return layouter.coordinate(location: location)
    }

    func enginePlay() {
        engine.evaluate(Int.max, time: 2) { (info, completed) in
            DispatchQueue.main.async {
                if completed {
                    self.engine.move(info.bestMove)
                    
                    // TODO: refactor?
                    let move = FEngineMove()
                    move.fromFile = info.fromFile
                    move.fromRank = info.fromRank
                    move.toFile = info.toFile
                    move.toRank = info.toRank
                    move.rawMoveValue = info.bestMove
                    self.state.lastMove = move
                    
                    self.animateState { }
                }
                self.infoChanged?(info)
            }
        }
    }
    
    func playEngineIfPossible() {
        if engine.isWhite() && playAgainstComputer == .white {
            enginePlay()
        }
        if !engine.isWhite() && playAgainstComputer == .black {
            enginePlay()
        }
    }
    
    func newGame(black: Bool) {
        engine.setFEN(StartPosFEN)
        if black {
            playAgainstComputer = .white
        }
        engineChanged()
    }

    func undoMove() {
        if engine.isAnalyzing() {
            engine.stop()
            if engine.canUndoMove() {
                engine.undoMove() // user move only
            }
        } else {
            if engine.canUndoMove() {
                engine.undoMove() // engine move
            }
            if engine.canUndoMove() {
                engine.undoMove() // user move
            }
        }
        playEngineIfPossible()
        engineChanged()
    }

    func redoMove() {
        if engine.isAnalyzing() {
            engine.stop()
            if engine.canRedoMove() {
                engine.redoMove() // user move only
            }
        } else {
            if engine.canRedoMove() {
                engine.redoMove() // engine move
            }
            if engine.canRedoMove() {
                engine.redoMove() // user move
            }
        }
        playEngineIfPossible()
        engineChanged()
    }

    func setPGN(pgn: String) {
        engine.setPGN(pgn)
        engineChanged()
    }
    
    func engineChanged() {
        state.boardState = engine.state
        state.possibleMoves = nil
        state.lastMove = nil
        infoChanged?(nil)
        
        animateState({ })
    }
}
