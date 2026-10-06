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

    private var toMove: Bool {
        session.isWhiteToMove == isWhite && session.gameEnd == .none
    }

    private var name: String {
        GameText.name(of: player, isWhite: isWhite, opponent: opponent)
    }

    private var detail: String {
        GameText.sideDetail(of: player, isWhite: isWhite, opponent: opponent, toMove: toMove)
    }

    @Environment(\.colorScheme) private var colorScheme
    @ScaledMetric(relativeTo: .headline) private var nameSize: CGFloat = 18

    var body: some View {
        HStack(spacing: 8) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text(name)
                    .font(.system(size: nameSize, weight: .semibold, design: .serif))
                    .foregroundStyle(Walnut.textPrimary)
                    .lineLimit(1)
                // The accent says whose move it is
                Text(detail)
                    .font(.footnote.weight(toMove ? .semibold : .regular))
                    .foregroundStyle(toMove ? Color.accentColor : Walnut.textSecondary)
                    .lineLimit(1)
            }

            Spacer(minLength: 0)

            let captured = session.capturedPieces(white: isWhite)
            if !captured.isEmpty {
                HStack(spacing: 0) {
                    ForEach(captured, id: \.self) { piece in
                        SquareView(piece: Piece(name: piece, file: 0, rank: 0))
                            .frame(width: 22, height: 22)
                    }
                }
                // The black pieces are dark: in dark mode they sit on a light square's color
                .padding(.horizontal, colorScheme == .dark ? 6 : 0)
                .background(colorScheme == .dark ? Walnut.lightSquare : .clear, in: Capsule())
            }

            if let points = session.materialPoints(white: isWhite) {
                Text(points)
                    .font(.footnote)
                    .foregroundStyle(Walnut.textSecondary)
            }
        }
        .padding(.horizontal, 2)
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

#Preview("Dark") {
    VStack(alignment: .leading) {
        PlayerRow(session: GameSession(state: GameState(pgn: "1. e4 e5 2. Nf3 Nf6 3. Nxe5 d6 4. Nc3 dxe5 *")), isWhite: false)
        PlayerRow(session: GameSession(state: GameState(pgn: "1. e4 e5 2. Nf3 Nf6 3. Nxe5 d6 4. Nc3 dxe5 *")), isWhite: true)
    }
    .padding()
    .background(Walnut.background)
    .preferredColorScheme(.dark)
}
