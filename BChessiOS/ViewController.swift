//
//  ViewController.swift
//  BChessiOS
//
//  Created by Jean Bovet on 3/2/18.
//  Copyright © 2018 Jean Bovet. All rights reserved.
//

import UIKit

class ViewController: UIViewController {

    let engine = FEngine()

    var chessView: ChessView {
        get {
            return self.view as! ChessView
        }
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        chessView.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(chessViewTapped(gesture:))))
        
        chessView.state = engine.state
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        chessView.layout()
    }

    func enginePlay() {
        engine.evaluate(4) { (info, completed) in
            if completed {
                DispatchQueue.main.async {
                    self.engine.move(info.bestMove)
                    
                    // TODO: refactor?
                    let move = FEngineMove()
                    move.fromFile = info.fromFile
                    move.fromRank = info.fromRank
                    move.toFile = info.toFile
                    move.toRank = info.toRank
                    move.rawMoveValue = info.bestMove
                    self.chessView.lastMove = move

                    self.applyState { }
                }
            }
        }
    }
    
    func applyState(_ completion: (() -> Void)?) {
        UIView.animate(withDuration: 0.3, delay: 0, options: .curveLinear, animations: {
            self.chessView.state = self.engine.state
        }, completion: { completed in
            completion?()
        })
    }
    
    @objc func chessViewTapped(gesture: UITapGestureRecognizer) {
        let loc = gesture.location(in: gesture.view)
        guard let (file, rank) = chessView.coordinate(location: loc) else {
            return
        }
        
        if !handleUserInitiatedMove(file: file, rank: rank) {
            showPossibleMoves(file: file, rank: rank)
        }
    }
    
    func handleUserInitiatedMove(file: UInt, rank: UInt) -> Bool {
        for move in chessView.possibleMoves {
            if move.toRank == rank && move.toFile == file {
                chessView.possibleMoves = []
                engine.move(move.rawMoveValue)
                applyState {
                    self.enginePlay()
                }
                return true
            }
        }
        return false
    }
    
    func showPossibleMoves(file: UInt, rank: UInt) {
        let moves = engine.moves(at: UInt(rank), file: UInt(file))
        chessView.possibleMoves = moves
    }
}

