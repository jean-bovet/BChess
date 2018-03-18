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
            if state.possibleMoves != nil {
                state.possibleMoves = nil
                animateState { }
            } else {
                showPossibleMoves(file: file, rank: rank)
            }
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
        state.possibleMoves = nil
        engine.move(move.rawMoveValue)
        animateState({
            self.enginePlay()
        })
    }
    
    func showPossibleMoves(file: UInt, rank: UInt) {
        let moves = engine.moves(at: UInt(rank), file: UInt(file))
        state.possibleMoves = moves
        animateState({ })
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
    
    func newGame() {
        engine.setFEN(StartPosFEN)
        state.boardState = engine.state
        state.possibleMoves = nil
        state.lastMove = nil
        infoChanged?(nil)
        animateState({ })
    }

}
