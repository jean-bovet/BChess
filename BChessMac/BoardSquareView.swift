//
//  BackgroundSquareView.swift
//  BChessMac
//
//  Created by Jean Bovet on 12/10/17.
//  Copyright © 2017 Jean Bovet. All rights reserved.
//

import Cocoa

class BoardSquareView: NSView {

    var rank = 0
    var file = 0
    
    var fromIndicator = false {
        didSet {
            if fromIndicator {
                self.layer?.borderColor = NSColor.orange.cgColor
                self.layer?.borderWidth = 2.0
            } else {
                self.layer?.borderColor = nil
                self.layer?.borderWidth = 0.0
            }
        }
    }
    
    var toIndicator = false {
        didSet {
            if toIndicator {
                self.layer?.borderColor = NSColor.orange.cgColor
                self.layer?.borderWidth = 3.0
            } else {
                self.layer?.borderColor = nil
                self.layer?.borderWidth = 0.0
            }
        }
    }
    
    var blackSquare = false {
        didSet {
            updateBackground()
        }
    }
    
    override var tag: Int {
        return 100 + rank * 8 + file
    }
    
    func updateBackground() {
        if blackSquare {
            self.layer?.backgroundColor = NSColor.gray.cgColor
        } else {
            self.layer?.backgroundColor = NSColor(red: 0.9, green: 0.9, blue: 0.9, alpha: 1).cgColor
        }
    }
    
    func clear() {
        fromIndicator = false
        toIndicator = false
    }
}
