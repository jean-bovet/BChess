//
//  ViewController.swift
//  BChessMac
//
//  Created by Jean Bovet on 12/10/17.
//  Copyright © 2017 Jean Bovet. All rights reserved.
//

import Cocoa

class ChessViewController: NSViewController, ChessViewInformationDelegate {

    @IBOutlet var chessView: ChessView!
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

}

