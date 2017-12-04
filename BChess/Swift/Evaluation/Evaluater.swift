//
//  MinimaxEvaluater.swift
//  BChess
//
//  Created by Jean Bovet on 11/24/17.
//  Copyright © 2017 Jean Bovet. All rights reserved.
//

import Foundation

enum Evaluater {
    case Minimize
    case Maximize
    
    var inverse: Evaluater {
        switch self {
        case .Maximize:
            return .Minimize
        case .Minimize:
            return .Maximize
        }
    }
    
    var startValue: Int {
        switch self {
        case .Maximize:
            return Int.min
        case .Minimize:
            return Int.max
        }
    }
    
    func isBestValue(current: Int, new: Int) -> Bool {
        switch self {
        case .Maximize:
            return new > current
        case .Minimize:
            return new < current
        }
    }
}

