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
    let state = ChessViewState()
    
    let attributedInfo = EngineInfo()
    var actions = [UIAction]()
    
    @IBOutlet weak var chessView: ChessView!
    @IBOutlet weak var infoTextView: UITextView!
        
    override func viewDidLoad() {
        super.viewDidLoad()
        
        navigationController?.setNavigationBarHidden(true, animated: false)
        
        initializeActions()
        
        engine.useOpeningBook = true
        
        chessView.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(chessViewTapped(gesture:))))
        view.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(backgroundViewTapped(gesture:))))
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        updateState()
    }
    
    // MARK: - Init -
    
    func initializeActions() {
        actions.append(UIActionNewGame(viewController: self))
    }
    
    // MARK: - State -

    func updateState() {
        state.layouter.viewSize = chessView.bounds.size
        state.update(state: engine.state)
        chessView.state = state
        infoTextView.attributedText = attributedInfo.information(forInfo: nil, engine: engine)
    }
    
    func animateUpdateState(_ completion: CompletionBlock?) {
        UIView.animate(withDuration: 0.3, delay: 0, options: .curveLinear, animations: {
            self.updateState()
        }, completion: { completed in
            completion?()
        })
    }

    // MARK: - User Actions -

    @IBAction func actionsTapped(_ sender: Any) {
        let presenter = UIActionPresenter()
        presenter.present(parentViewController: self, actions: actions) {

        }
    }
    
    @objc func chessViewTapped(gesture: UITapGestureRecognizer) {
        let loc = gesture.location(in: gesture.view)
        guard let (file, rank) = coordinate(location: loc) else {
            return
        }
        
        if !handleUserInitiatedMove(file: file, rank: rank) {
            showPossibleMoves(file: file, rank: rank)
        }
    }
    
    @objc func backgroundViewTapped(gesture: UITapGestureRecognizer) {
        if let navBar = navigationController {
            let hidden = navBar.isNavigationBarHidden
            navBar.setNavigationBarHidden(!hidden, animated: true)
        }
    }
    
    // MARK: - Functions -
    
    func coordinate(location: CGPoint) -> (UInt, UInt)? {
        return state.layouter.coordinate(location: location)
    }
    
    func enginePlay() {
        engine.evaluate(Int.max, time: 5) { (info, completed) in
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
                    
                    self.animateUpdateState { }
                }
                self.infoTextView.attributedText = self.attributedInfo.information(forInfo: info, engine: self.engine)
            }
        }
    }
    
    func handleUserInitiatedMove(file: UInt, rank: UInt) -> Bool {
        if let moves = state.possibleMoves {
            for move in moves {
                if move.toRank == rank && move.toFile == file {
                    state.possibleMoves = nil
                    engine.move(move.rawMoveValue)
                    animateUpdateState {
                        self.enginePlay()
                    }
                    return true
                }
            }
        }
        return false
    }
    
    func showPossibleMoves(file: UInt, rank: UInt) {
        let moves = engine.moves(at: UInt(rank), file: UInt(file))
        state.possibleMoves = moves
        animateUpdateState { }
    }
    
    func newGame() {
        engine.setFEN(StartPosFEN)
        state.possibleMoves = nil
        state.lastMove = nil
        animateUpdateState { }
    }
}

