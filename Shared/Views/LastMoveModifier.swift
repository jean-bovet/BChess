//
//  LastMoveModifier.swift
//  BChess
//
//  Created by Jean Bovet on 1/10/21.
//  Copyright © 2021 Jean Bovet. All rights reserved.
//

import SwiftUI

/// Tints the two squares of the last move: honey while playing, green or red while practicing openings.
struct LastMoveModifier: ViewModifier {
    let rank: Int
    let file: Int
    let session: GameSession
    @AppStorage(AppSettings.highlightLastMoveKey) private var highlightLastMove = AppSettings.highlightLastMoveDefault
    
    func moveColor() -> Color {
        if session.mode.value == .train {
            if session.isValidOpeningMoves {
                return Color.green.opacity(0.55)
            } else {
                return Color.red.opacity(0.55)
            }
        } else {
            return Walnut.lastMove
        }
    }
    
    func isLastMoveSquare(_ rank: Int, _ file: Int) -> Bool {
        if let move = session.lastMove {
            return (move.fromRank == rank && move.fromFile == file) || (move.toRank == rank && move.toFile == file)
        } else {
            return false
        }
    }

    func body(content: Content) -> some View {
        return content
            .overlay {
                if AppSettings.showsLastMoveTint(mode: session.mode.value, highlightLastMove: highlightLastMove),
                   isLastMoveSquare(rank, file) {
                    moveColor()
                }
            }
    }
}
