//
//  BackgroundSquareView.swift
//  BChessMac
//
//  Created by Jean Bovet on 12/10/17.
//  Copyright © 2017 Jean Bovet. All rights reserved.
//

import Cocoa

class BackgroundSquareView: NSView {

    var rank = 0
    var file = 0
    
    override var tag: Int {
        return 100 + rank * 8 + file
    }
}
