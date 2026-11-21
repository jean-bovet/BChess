//
//  GameResult.swift
//  BChess
//
//  How a game's line ended: who won (or a draw) and why.
//

/// The result of the current line, whichever position is on screen (`GameSession.result`).
nonisolated struct GameResult: Equatable, Sendable {

    enum Winner: Equatable, Sendable {
        case white
        case black
        case draw
    }

    let winner: Winner
    /// Why the line ended; never `.none`.
    let reason: GameEnd
}
