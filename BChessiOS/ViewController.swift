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
    
    var relaxingMode = false {
        didSet {
            relaxModeChanged()
        }
    }
    
    @IBOutlet weak var chessView: ChessView!
    @IBOutlet weak var infoTextView: UITextView!
    
    override var prefersStatusBarHidden: Bool {
        return relaxingMode
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        
        interaction = ChessViewInteraction(view: chessView, engine: engine, animateState: { [unowned self] completion in
            self.animateUpdateState({
                completion()
            })
        })
        
        interaction.infoChanged = { [unowned self] info in
            self.infoTextView.attributedText = self.attributedInfo.information(forInfo: info, engine: self.engine)
        }
        
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
    }
    
    func animateUpdateState(_ completion: CompletionBlock?) {
        UIView.animate(withDuration: 0.3, delay: 0, options: .curveLinear, animations: { [unowned self] in
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
        relaxingMode = !relaxingMode
    }
    
    func relaxModeChanged() {
        navigationController?.setNavigationBarHidden(relaxingMode, animated: true)
        
        setNeedsStatusBarAppearanceUpdate()
        
        UIView.animate(withDuration: 0.3, animations: { [unowned self] in
            if self.relaxingMode {
                self.view.backgroundColor = .black
            } else {
                self.view.backgroundColor = .white
            }
        })
    }
}

