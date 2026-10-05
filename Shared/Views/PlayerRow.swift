//
//  PlayerRow.swift
//  BChess
//
//  Created by Jean Bovet on 1/10/21.
//  Copyright © 2021 Jean Bovet. All rights reserved.
//

import SwiftUI

/// One side of the board: whose move it is, who plays it, and what it has captured.
struct PlayerRow: View {

    let session: GameSession
    let isWhite: Bool

    private var player: GamePlayer {
        isWhite ? session.gameState.white : session.gameState.black
    }

    private var opponent: GamePlayer {
        isWhite ? session.gameState.black : session.gameState.white
    }

    private var label: String {
        let name = GameText.name(of: player, isWhite: isWhite, opponent: opponent)
        let toMove = session.isWhiteToMove == isWhite && session.gameEnd == .none
        guard let detail = GameText.detail(of: player, toMove: toMove) else {
            return name
        }
        return "\(name) \u{00B7} \(detail)"
    }

    var body: some View {
        HStack {
            Image(systemName: "circle.fill")
                .imageScale(.small)
                .foregroundStyle(.tint)
                .hide(session.isWhiteToMove != isWhite)
            Image(systemName: player.computer ? "cpu" : "person.fill")
            Text(label)

            HStack(spacing: 0) {
                ForEach(session.capturedPieces(white: isWhite), id: \.self) { piece in
                    SquareView(piece: Piece(name: piece, file: 0, rank: 0))
                        .frame(width: 24, height: 24)
                }
            }

            if let points = session.materialPoints(white: isWhite) {
                Text(points)
            }
        }
        .accessibilityElement(children: .combine)
    }
}

#Preview("To move") {
    VStack(alignment: .leading) {
        PlayerRow(session: GameSession(state: GameState(pgn: "1. e4 e5 *", white: .human, black: .human)), isWhite: false)
        PlayerRow(session: GameSession(state: GameState(pgn: "1. e4 e5 *", white: .human, black: .human)), isWhite: true)
    }
}

#Preview("Captures") {
    VStack(alignment: .leading) {
        PlayerRow(session: GameSession(state: GameState(pgn: "1. e4 e5 2. Nf3 Nf6 3. Nxe5 d6 4. Nc3 dxe5 *")), isWhite: false)
        PlayerRow(session: GameSession(state: GameState(pgn: "1. e4 e5 2. Nf3 Nf6 3. Nxe5 d6 4. Nc3 dxe5 *")), isWhite: true)
    }
}
