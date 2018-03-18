//
//  ViewController.swift
//  BChessMac
//
//  Created by Jean Bovet on 12/10/17.
//  Copyright © 2017 Jean Bovet. All rights reserved.
//

import Cocoa

class ChessViewController: NSViewController {

    @IBOutlet weak var chessView: ChessView!
    @IBOutlet weak var stackView: NSStackView!
    @IBOutlet weak var gameInfoScrollView: NSScrollView!
    @IBOutlet var gameInfoTextView: NSTextView!
    
    let engine = FEngine()
    let state = ChessViewState()
    let engineInfo = MacEngineInfo()
    var info: FEngineInfo?
    
    var interaction: ChessViewInteraction!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        restoreFromDefaults()
        
        registerGesture()
        
        loadOpenings()
        
        interaction = ChessViewInteraction(view: chessView, engine: engine, animateState: { [unowned self] completion in
            NSAnimationContext.runAnimationGroup({ _ in
                NSAnimationContext.current.duration = 0.5
                NSAnimationContext.current.timingFunction = CAMediaTimingFunction(name: kCAAnimationLinear)
                self.chessView.stateChanged()
            }, completionHandler: {
                completion()
            })
        })

        interaction.infoChanged = { [unowned self] info in
            self.info = info
            self.updateGameInfo()
        }
        
        engine.updateCallback = { [unowned self] in
            self.updateUI()
            self.saveToDefaults()
        }
        
        updateUI()
    }
    
    func loadOpenings() {
        engine.useOpeningBook = true

        let path = Bundle.main.path(forResource: "Openings", ofType: "pgn")
        assert(path != nil)
        
        let pgn = try! String(contentsOfFile: path!)

        assert(engine.loadOpening(pgn))
    }
    
    func updateUI() {
        chessView.needsLayout = true
        
        chessView.state = state
        chessView.state?.boardState = engine.state

        chessView.stateChanged()
        
        updateGameInfo()
    }
    
    func updateGameInfo() {
        let text = NSMutableAttributedString()
        text.append(engineInfo.attributedString(forInfo: info, engine: engine))
        text.append(NSAttributedString(string: "\n\n"))
        text.append(NSAttributedString(string: engine.pgnFormattedForDisplay()))
        gameInfoTextView.textStorage?.setAttributedString(text)
    }
    
    // MARK: Gesture

    func registerGesture() {
        view.addGestureRecognizer(NSClickGestureRecognizer(target: self, action: #selector(clickDetected(sender:))))
    }
    
    @objc func clickDetected(sender: NSClickGestureRecognizer) {
        let loc = sender.location(in: chessView)
        interaction.handleTap(atLocation: loc)
    }
    
    // MARK: Defaults

    func saveToDefaults() {
        UserDefaults.standard.set(engine.pgn(), forKey: "pgn")
    }
    
    func restoreFromDefaults() {
        if let pgn = UserDefaults.standard.string(forKey: "pgn") {
            engine.setPGN(pgn)
        }
    }
    
    // MARK: UI
    
    override func validateMenuItem(_ menuItem: NSMenuItem) -> Bool {
        if menuItem.action == #selector(playAgaintComputerWhite) {
            menuItem.state = interaction.playAgainstComputer == .white ? .on : .off
        }
        if menuItem.action == #selector(playAgaintComputerBlack) {
            menuItem.state = interaction.playAgainstComputer == .black ? .on : .off
        }
        if menuItem.action == #selector(playAgaintHuman) {
            menuItem.state = interaction.playAgainstComputer == .human ? .on : .off
        }
        if menuItem.action == #selector(level) {
            menuItem.state = engine.thinkingTime == TimeInterval(menuItem.tag) ? .on : .off
        }
        if menuItem.action == #selector(undoMove) {
            return engine.canUndoMove()
        }
        if menuItem.action == #selector(redoMove) {
            return engine.canRedoMove()
        }
        if menuItem.action == #selector(startAnalysis) {
            if engine.isAnalyzing() {
                menuItem.title = "Stop Analyze"
            } else {
                menuItem.title = "Start Analyze"
            }
        }
        if menuItem.action == #selector(toggleGameInfo) {
            if isGameInfoVisible() {
                menuItem.title = "Hide Info"
            } else {
                menuItem.title = "Show Info"
            }
        }
        return true
    }
    
    // MARK: Menu Edit

    @IBAction func copyPosition(_ sender: Any?) {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(engine.fen(), forType: .string)
    }

    @IBAction func copyGame(_ sender: Any?) {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(engine.pgn(), forType: .string)
    }

    @IBAction func paste(_ sender: Any?) {
        let pasteboard = NSPasteboard.general
        if let text = pasteboard.string(forType: .string) {
            if !engine.setFEN(text) {
                // Could not past FEN, maybe PGN?
                engine.setPGN(text);
            }
            updateUI()
            saveToDefaults()
        }
    }
    
    // MARK: Menu Game

    @IBAction func newGame(_ sender: NSMenuItem) {
        interaction.newGame()
    }
    
    @IBAction func playAgaintComputerWhite(_ sender: NSMenuItem) {
        interaction.playAgainstComputer = .white
    }

    @IBAction func playAgaintComputerBlack(_ sender: NSMenuItem) {
        interaction.playAgainstComputer = .black
    }

    @IBAction func playAgaintHuman(_ sender: NSMenuItem) {
        interaction.playAgainstComputer = .human
    }

    @IBAction func undoMove(_ sender: NSMenuItem) {
        engine.undoMove()
    }

    @IBAction func redoMove(_ sender: NSMenuItem) {
        engine.redoMove()
    }

    @IBAction func startAnalysis(_ sender: NSMenuItem) {
        if (engine.isAnalyzing()) {
            engine.stop()
        } else {
            engine.analyze({ info, completed in
                DispatchQueue.main.async { [unowned self] in
                    self.info = info
                    self.updateGameInfo()
                }
            })
        }
    }

    // MARK: Menu Level
    
    @IBAction func level(_ sender: NSMenuItem) {
        engine.thinkingTime = TimeInterval(sender.tag)
    }
    
    // MARK: Menu View
    
    func isGameInfoVisible() -> Bool {
        let visible = stackView.visibilityPriority(for: gameInfoScrollView) != NSStackView.VisibilityPriority.notVisible
        return visible
    }
    
    @IBAction func toggleGameInfo(_ sender: Any) {
        if isGameInfoVisible() {
            stackView.setVisibilityPriority(NSStackView.VisibilityPriority.notVisible, for: gameInfoScrollView)
        } else {
            stackView.setVisibilityPriority(NSStackView.VisibilityPriority.mustHold, for: gameInfoScrollView)
        }
    }
}

