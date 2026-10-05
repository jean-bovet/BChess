//
//  Square.swift
//  BChess
//
//  Created by Jean Bovet on 1/10/21.
//  Copyright © 2021 Jean Bovet. All rights reserved.
//

import Foundation

struct Square: Identifiable {
    var id: String {
        return piece?.name ?? "empty-\(position.rank)-\(position.file)"
    }
    let position: Position
    let piece: Piece?
}
