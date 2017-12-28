//
//  ViewController.swift
//  BChessMac
//
//  Created by Jean Bovet on 12/10/17.
//  Copyright © 2017 Jean Bovet. All rights reserved.
//

import Cocoa

class ChessViewController: NSViewController {

    @IBOutlet weak var chessView: BoardView!
    @IBOutlet weak var stackView: NSStackView!
    @IBOutlet weak var gameInfoScrollView: NSScrollView!
    @IBOutlet var gameInfoTextView: NSTextView!
    
    var engine : FEngine {
        return chessView.engine
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        restoreFromDefaults()
        
        engine.updateCallback = {
            self.updateUI()
            self.saveToDefaults()
        }
        
        updateUI()
    }
    
    func updateUI() {
        chessView.invalidateUI()
        updateGameInfo()
    }
    
    func updateGameInfo() {
        let text = NSMutableAttributedString()
        text.append(chessView.infoLine)
        text.append(NSAttributedString(string: "\n\n"))
        text.append(NSAttributedString(string: engine.pgnFormattedForDisplay()))
        gameInfoTextView.textStorage?.setAttributedString(text)
    }
    
    func saveToDefaults() {
        UserDefaults.standard.set(engine.pgn(), forKey: "pgn")
    }
    
    func restoreFromDefaults() {
        if let pgn = UserDefaults.standard.string(forKey: "pgn") {
            engine.setPGN(pgn)
        }
    }
    
    override func validateMenuItem(_ menuItem: NSMenuItem) -> Bool {
        if menuItem.action == #selector(playAgaintComputerWhite) {
            menuItem.state = chessView.playAgainstComputer == .white ? .on : .off
        }
        if menuItem.action == #selector(playAgaintComputerBlack) {
            menuItem.state = chessView.playAgainstComputer == .black ? .on : .off
        }
        if menuItem.action == #selector(playAgaintHuman) {
            menuItem.state = chessView.playAgainstComputer == .human ? .on : .off
        }
        if menuItem.action == #selector(levelEasy) {
            menuItem.state = engine.level == Easy ? .on : .off
        }
        if menuItem.action == #selector(levelMedium) {
            menuItem.state = engine.level == Medium ? .on : .off
        }
        if menuItem.action == #selector(levelHard) {
            menuItem.state = engine.level == Hard ? .on : .off
        }
        if menuItem.action == #selector(undoMove) {
            return engine.canUndoMove()
        }
        if menuItem.action == #selector(redoMove) {
            return engine.canRedoMove()
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
            chessView.invalidateUI()
        }
    }
    
    // MARK: Menu Game

    @IBAction func newGame(_ sender: NSMenuItem) {
        chessView.newGame()
    }
    
    @IBAction func playAgaintComputerWhite(_ sender: NSMenuItem) {
        chessView.playAgainstComputer = .white
    }

    @IBAction func playAgaintComputerBlack(_ sender: NSMenuItem) {
        chessView.playAgainstComputer = .black
    }

    @IBAction func playAgaintHuman(_ sender: NSMenuItem) {
        chessView.playAgainstComputer = .human
    }

    @IBAction func undoMove(_ sender: NSMenuItem) {
        engine.undoMove()
    }

    @IBAction func redoMove(_ sender: NSMenuItem) {
        engine.redoMove()
    }

    @IBAction func debugEvaluate(_ sender: NSMenuItem) {
        engine.debugEvaluate()
    }

    // MARK: Menu Level
    
    @IBAction func levelEasy(_ sender: NSMenuItem) {
        engine.level = Easy
    }

    @IBAction func levelMedium(_ sender: NSMenuItem) {
        engine.level = Medium
    }

    @IBAction func levelHard(_ sender: NSMenuItem) {
        engine.level = Hard
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

