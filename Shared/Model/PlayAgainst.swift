//
//  PlayAgainst.swift
//  BChess
//
//  Created by Jean Bovet on 1/10/21.
//  Copyright © 2021 Jean Bovet. All rights reserved.
//

import Foundation

enum PlayAgainst: Int {
    case white
    case black
    case human
}

extension Int {

    func actual(rotated: Bool) -> Int {
        if rotated {
            return 7 - self
        } else {
            return self
        }
    }
    
}
