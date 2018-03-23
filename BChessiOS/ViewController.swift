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

    var zenMode = false {
        didSet {
            zenModeChanged()
        }
    }
    
    @IBOutlet weak var chessView: ChessView!
    @IBOutlet weak var upperInfoTextView: UITextView!
    @IBOutlet weak var infoTextView: UITextView!
    @IBOutlet weak var actionsStackView: UIStackView!
    
    override var prefersStatusBarHidden: Bool {
        return zenMode
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        
        interaction = ChessViewInteraction(view: chessView, engine: engine, animateState: { [unowned self] completion in
            self.animateUpdateState({
                completion()
            })
        })
        
        interaction.infoChanged = { [unowned self] info in
            self.upperInfoTextView.attributedText = self.attributedInfo.upperInformation(forInfo: info, engine: self.engine)
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
        actions.append(UIAction(title: NSLocalizedString("Undo Move", comment: ""),
                                executeBlock: { [unowned self] action, completion in
                                    self.interaction.undoMove()
                                    completion()
            },
                                enabledBlock: { [unowned self] in
                                    return self.interaction.engine.canUndoMove()
        }))
        
        actions.append(UIAction(title: NSLocalizedString("Redo Move", comment: ""),
                                executeBlock: { [unowned self] action, completion in
                                    self.interaction.redoMove()
                                    completion()
            },
                                enabledBlock: { [unowned self] in
                                    return self.interaction.engine.canRedoMove()
        }))

        actions.append(UIAction(title: NSLocalizedString("New Game (White)", comment: ""),
                                executeBlock: { [unowned self] action, completion in
                                    self.interaction.newGame(black: false)
                                    completion()
        }))
        
        actions.append(UIAction(title: NSLocalizedString("New Game (Black)", comment: ""),
                                executeBlock: { [unowned self] action, completion in
                                    self.interaction.newGame(black: true)
                                    completion()
        }))
        
        actions.append(UIAction(title: NSLocalizedString("Copy Game", comment: ""),
                                executeBlock: { [unowned self] action, completion in
                                    UIPasteboard.general.string = self.interaction.engine.pgn()
                                    completion()
        }))

        actions.append(UIAction(title: NSLocalizedString("Paste Game", comment: ""),
                                executeBlock: { [unowned self] action, completion in
                                    if UIPasteboard.general.hasStrings, let pgn = UIPasteboard.general.string {
                                        self.interaction.setPGN(pgn: pgn)
                                    }
                                    completion()
        }))

        presenter = UIActionPresenter(actions: actions, viewController: self)
    }
    
    func refreshButtons() {
        for view in actionsStackView.arrangedSubviews {
            view.removeFromSuperview()
        }
        
        for button in presenter.buttons {
            actionsStackView.addArrangedSubview(button)
        }
    }

    // MARK: - State -

    func updateState() {
        state.boardState = engine.state
        chessView.state = state
        presenter.update()
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
        zenMode = !zenMode
    }
    
    func zenModeChanged() {
        navigationController?.setNavigationBarHidden(zenMode, animated: true)
        
        setNeedsStatusBarAppearanceUpdate()
        
        UIView.animate(withDuration: 0.3, animations: { [unowned self] in
            if self.zenMode {
                self.view.backgroundColor = .black
            } else {
                self.view.backgroundColor = .white
            }
            self.actionsStackView.isHidden = self.zenMode
        })
    }
}

