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
    
    var presenter: UIActionPresenter!

    var relaxingMode = false {
        didSet {
            relaxModeChanged()
        }
    }
    
    @IBOutlet weak var chessView: ChessView!
    @IBOutlet weak var infoTextView: UITextView!
    @IBOutlet weak var actionsStackView: UIStackView!
    
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
        
        chessView.state = state // TODO refactor into interaction?

        restoreFromDefaults()
        
        interaction.playEngineIfPossible()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        updateState()
        refreshButtons()
    }
    
    // MARK: - Actions -
    
    func initializeActions() {
        actions.append(UIActionNewGame())
        actions.append(UIActionTakeBack())
        actions.append(UIActionCopyGame())
        actions.append(UIActionPasteGame())

        presenter = UIActionPresenter(actions: actions, viewController: self)
    }
    
    func refreshButtons() {
        for view in actionsStackView.arrangedSubviews {
            view.removeFromSuperview()
        }
        
        for button in presenter.actionButtons() {
            actionsStackView.addArrangedSubview(button)
        }
    }

    // MARK: - State -

    func updateState() {
        state.boardState = engine.state
        chessView.state = state
        saveToDefaults()
    }
    
    func animateUpdateState(_ completion: CompletionBlock?) {
        if self.view.window == nil {
            // No animation if no window
            chessView.animated = false
            updateState()
            chessView.animated = true
        } else {
            updateState()
        }
        completion?()
    }

    // MARK: - Defaults-
    
    func saveToDefaults() {
        UserDefaults.standard.set(engine.pgn(), forKey: "pgn")
    }
    
    func restoreFromDefaults() {
        if let pgn = UserDefaults.standard.string(forKey: "pgn") {
            interaction.setPGN(pgn: pgn)
        }
    }

    // MARK: - User Actions -
        
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

