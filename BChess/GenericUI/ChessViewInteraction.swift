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
    
    enum PlayAgainst: Int {
        case white
        case black
        case human
    }
    
    var playAgainst: PlayAgainst = .black
    
    enum PlayLevel: Int {
        case _2s
        case _5s
        case _10s
        case _15s
    }
    
    var playLevel: PlayLevel = ._5s
    
    init(view: ChessView, state: ChessViewState, engine: FEngine, animateState: @escaping AnimateStateBlock) {
        self.view = view
        self.engine = engine
        self.animateState = animateState
        promotionPicker = ChessViewPromotionPicker(layouter: view.layouter, factory: view.piecesCache.factory, parent: view)
        
        self.view.state = state
        
        loadOpenings()
    }
    
    func loadOpenings() {
        engine.useOpeningBook = true
        
        let path = Bundle.main.path(forResource: "Openings", ofType: "pgn")
        assert(path != nil)
        
        let pgn = try! String(contentsOfFile: path!)
        let result = engine.loadOpening(pgn);
        assert(result)
    }
    
    func saveToDefaults() {
        UserDefaults.standard.set(playAgainst.rawValue, forKey: "playAgainst")
        UserDefaults.standard.set(playLevel.rawValue, forKey: "playLevel")
        UserDefaults.standard.set(engine.pgn(), forKey: "pgn")
    }
    
    func restoreFromDefaults() {
        if let playAgainst = ChessViewInteraction.PlayAgainst(rawValue: UserDefaults.standard.integer(forKey: "playAgainst")) {
            self.playAgainst = playAgainst
        }
        if let playLevel = ChessViewInteraction.PlayLevel(rawValue: UserDefaults.standard.integer(forKey: "playLevel")) {
            self.playLevel = playLevel
        }
        if let pgn = UserDefaults.standard.string(forKey: "pgn") {
            setPGN(pgn: pgn)
        }
        playLevelChanged()
        playAgainstChanged()
    }

    func playAgainstChanged() {
        view.rotated = playAgainst == .white
        playEngineIfPossible()
    }
    
    func playLevelChanged() {
        switch playLevel {
        case ._2s:
            engine.thinkingTime = 2
            
        case ._5s:
            engine.thinkingTime = 5
            
        case ._10s:
            engine.thinkingTime = 10
            
        case ._15s:
            engine.thinkingTime = 15
        }
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
        engine.evaluate { (info, completed) in
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
        if engine.isWhite() && playAgainst == .white {
            enginePlay()
        }
        if !engine.isWhite() && playAgainst == .black {
            enginePlay()
        }
    }
    
    func newGame(playAgainstWhite: Bool) {
        engine.setFEN(StartPosFEN)
        if playAgainstWhite {
            playAgainst = .white
        } else {
            playAgainst = .black
        }
        playAgainstChanged()
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
