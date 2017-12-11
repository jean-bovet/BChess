//
//  ChessView.swift
//  BChessMac
//
//  Created by Jean Bovet on 12/11/17.
//  Copyright © 2017 Jean Bovet. All rights reserved.
//

import Cocoa

class ChessView: NSView {

    let engine = UCIEngine()

    override func encodeRestorableState(with coder: NSCoder) {
        super.encodeRestorableState(with: coder)
        coder.encode(engine.get(), forKey: "fen")
    }
    
    override func restoreState(with coder: NSCoder) {
        super.restoreState(with: coder)
        if let fen = coder.decodeObject(forKey: "fen") as? String {
            engine.set(fen: fen)
            self.needsLayout = true
        }
    }

}
