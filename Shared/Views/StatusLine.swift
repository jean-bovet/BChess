//
//  StatusLine.swift
//  BChess
//
//  One sentence about the game: whose move it is, or how it ended.
//

import SwiftUI

struct StatusLine: View {

    let session: GameSession

    private var lastMove: String? {
        session.game.nodes[session.currentMoveUUID].map {
            GameText.moveLabel(number: Int($0.moveNumber), isWhite: $0.whiteMove, san: $0.name)
        }
    }

    var body: some View {
        Text(GameText.status(mode: session.mode.value, isThinking: session.isThinking, gameEnd: session.gameEnd,
                             white: session.gameState.white, black: session.gameState.black,
                             isWhiteToMove: session.isWhiteToMove, lastMove: lastMove))
            .font(.subheadline)
            .foregroundStyle(.secondary)
            .accessibilityIdentifier("status")
    }
}

#if DEBUG
#Preview("Your move") {
    PreviewScenarios.statusLineYourMove.view()
}

#Preview("Checkmate") {
    PreviewScenarios.statusLineCheckmate.view()
}
#endif
