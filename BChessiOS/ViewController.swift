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
    
    var interaction: ChessViewInteraction!
    
    var actions = [UIAction]()
    
    @IBOutlet weak var chessView: ChessView!
    @IBOutlet weak var infoTextView: UITextView!
        
    override func viewDidLoad() {
        super.viewDidLoad()
        
        interaction = ChessViewInteraction(view: chessView, engine: engine, animateState: { completion in
            self.animateUpdateState({
                completion()
            })
        })

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
        state.boardState = engine.state
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

    func newGame() {
        interaction.newGame()
    }
    
    @IBAction func actionsTapped(_ sender: Any) {
        let presenter = UIActionPresenter()
        presenter.present(parentViewController: self, actions: actions) {

        }
    }
    
    @objc func chessViewTapped(gesture: UITapGestureRecognizer) {
        let loc = gesture.location(in: gesture.view)
        interaction.handleTap(atLocation: loc)
    }
    
    @objc func backgroundViewTapped(gesture: UITapGestureRecognizer) {
        if let navBar = navigationController {
            let hidden = navBar.isNavigationBarHidden
            navBar.setNavigationBarHidden(!hidden, animated: true)
        }
    }
    
}

