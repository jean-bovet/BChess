//
//  PieceSquareView.swift
//  BChessMac
//
//  Created by Jean Bovet on 12/10/17.
//  Copyright © 2017 Jean Bovet. All rights reserved.
//

import Cocoa

class PieceSquareView: NSImageView {

    var rank = 0
    var file = 0
    var move: FEngineMove? = nil
    
    var moveIndicator = false {
        didSet {
            if moveIndicator {
                self.layer?.backgroundColor = NSColor.yellow.withAlphaComponent(0.4).cgColor
            } else {
                self.layer?.backgroundColor = nil
            }
        }
    }
    
    var selected = false {
        didSet {
            if selected {
                self.layer?.backgroundColor = NSColor.yellow.withAlphaComponent(0.8).cgColor
            } else {
                self.layer?.backgroundColor = nil
            }
        }
    }
}
