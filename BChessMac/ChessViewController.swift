//
//  ViewController.swift
//  BChessMac
//
//  Created by Jean Bovet on 12/10/17.
//  Copyright © 2017 Jean Bovet. All rights reserved.
//

import Cocoa

class ChessViewController: NSViewController, ChessViewInformationDelegate {

    @IBOutlet var chessView: BoardView!
    @IBOutlet var infoLabel: NSTextField!

    var engine : UCIEngine {
        return chessView.engine
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        chessView.delegate = self
    }
    
    func chessViewEngineInfoDidChange(info: String) {
        DispatchQueue.main.async {
            self.infoLabel.stringValue = info
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
        if menuItem.action == #selector(depth4) {
            menuItem.state = chessView.searchDepth == 4 ? .on : .off
        }
        if menuItem.action == #selector(depth5) {
            menuItem.state = chessView.searchDepth == 5 ? .on : .off
        }
        if menuItem.action == #selector(depth6) {
            menuItem.state = chessView.searchDepth == 6 ? .on : .off
        }
        if menuItem.action == #selector(undoMove) {
            return chessView.engine.engine.canUndoMove()
        }
        if menuItem.action == #selector(redoMove) {
            return chessView.engine.engine.canRedoMove()
        }
        return true
    }
    
    // MARK: Menu Edit

    @IBAction func copy(_ sender: Any?) {
        let fen = engine.get()
        
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(fen, forType: .string)
    }
    
    @IBAction func paste(_ sender: Any?) {
        let pasteboard = NSPasteboard.general
        if let fen = pasteboard.string(forType: .string) {
            engine.set(fen: fen)
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
        chessView.engine.engine.undoMove()
        chessView.invalidateUI()
    }

    @IBAction func redoMove(_ sender: NSMenuItem) {
        chessView.engine.engine.redoMove()
        chessView.invalidateUI()
    }

    // MARK: Menu Level
    
    @IBAction func depth4(_ sender: NSMenuItem) {
        chessView.searchDepth = 4
    }

    @IBAction func depth5(_ sender: NSMenuItem) {
        chessView.searchDepth = 5
    }

    @IBAction func depth6(_ sender: NSMenuItem) {
        chessView.searchDepth = 6
    }

    
}

