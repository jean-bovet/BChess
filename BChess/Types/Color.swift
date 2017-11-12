//
//  Color.swift
//  BChess
//
//  Created by Jean Bovet on 11/10/17.
//  Copyright © 2017 Jean Bovet. All rights reserved.
//

import Foundation

enum Color: Int {
    case white
    case black
    
    var opposite: Color {
        switch self {
        case .white:
            return .black
        case .black:
            return .white
        }
    }
}

