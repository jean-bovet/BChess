//
//  Promotion.swift
//  BChess
//
//  A pawn move that waits for the player to choose the piece it becomes.
//

import Foundation

struct Promotion {
    let move: FEngineMove
    let isWhite: Bool

    /// The pieces to offer, the queen first, as the engine spells them: capitals for White.
    var pieceNames: [String] {
        let names = ["Q", "R", "B", "N"]
        return isWhite ? names : names.map { $0.lowercased() }
    }

    /// Where the promotion square is on screen, row 0 at the top and file 0 at the left, whichever side
    /// is at the bottom. The engine's ranks and files are the same for both orientations.
    static func screenRow(rank: Int, rotated: Bool) -> Int {
        7 - rank.actual(rotated: rotated)
    }

    static func screenFile(file: Int, rotated: Bool) -> Int {
        file.actual(rotated: rotated)
    }

    /// Whether the picker's column hangs below the promotion square (it stands in the upper half of the
    /// screen) rather than rising above it, so that it always opens toward the center of the board.
    /// `screenRow` counts from the top of the board, whichever side is at the bottom.
    static func dropsDown(screenRow: Int) -> Bool {
        screenRow < 4
    }
}
