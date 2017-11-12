//
//  PieceType.swift
//  BChess
//
//  Created by Jean Bovet on 11/10/17.
//  Copyright © 2017 Jean Bovet. All rights reserved.
//

import Foundation

enum PieceType {
    case none
    case pawn
    case bishop
    case knight
    case rook
    case queen
    case king
}

extension PieceType {
    var value: Int {
        switch self {
        case .none:
            return 0
        case .pawn:
            return 1
        case .rook:
            return 5
        case .knight:
            return 3
        case .bishop:
            return 3
        case .queen:
            return 9
        case .king:
            return 0
        }
    }
}
