//
//  LastMoveModifier.swift
//  BChess
//
//  Created by Jean Bovet on 1/10/21.
//  Copyright © 2021 Jean Bovet. All rights reserved.
//

import SwiftUI

struct LastMoveModifier: ViewModifier {
    let rank: Int
    let file: Int
    let document: ChessDocument
    
    func moveColor() -> Color {
        if document.mode.value == .train {
            if document.engine.isValidOpeningMoves() {
                return Color.green.opacity(0.8)
            } else {
                return Color.red.opacity(0.8)
            }
        } else {
            return Color.orange.opacity(0.8)
        }
    }
    
    func isLastMoveStart(_ rank: Int, _ file: Int) -> Bool {
        if let move = document.lastMove {
            return move.fromRank == rank && move.fromFile == file
        } else {
            return false
        }
    }

    func isLastMoveEnd(_ rank: Int, _ file: Int) -> Bool {
        if let move = document.lastMove {
            return move.toRank == rank && move.toFile == file
        } else {
            return false
        }
    }

    func body(content: Content) -> some View {
        return content
            .if(isLastMoveStart(rank, file)) { view in
                view.border(moveColor(), width: 3)
            }
            .if(isLastMoveEnd(rank, file)) { view in
                view.border(moveColor(), width: 5)
            }
    }
}
