//
//  Variation.swift
//  BChess
//
//  Created by Jean Bovet on 5/15/21.
//  Copyright © 2021 Jean Bovet. All rights reserved.
//

import Foundation

struct Variation: Identifiable {
    var id: String {
        return "\(index)"
    }
    let index: Int
    let from: Position
    let to: Position
    let label: String
}
