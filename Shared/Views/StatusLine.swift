//
//  StatusLine.swift
//  BChess
//
//  The one sentence the rest of the screen does not say: the mode, or why a position in the middle of a line cannot be played (the result banner says how the line ends). The line is always there
//  (blank during play), so a game end or a mode change never moves the board.
//

import SwiftUI

struct StatusLine: View {

    let session: GameSession

    private var status: String? {
        GameText.status(mode: session.mode.value, gameEnd: session.gameEnd)
    }

    /// The slot's height: one subheadline line of Latin text (18 pt at the default size). A fixed height, not the
    /// height of a line of text, because the line height of a script with taller fallback fonts (Arabic) is 2 pt more
    /// than the same line in English, and the board block, centred on the screen, would sit higher in that language.
    @ScaledMetric(relativeTo: .subheadline) private var slotHeight: CGFloat = 18

    var body: some View {
        // A sentence that shrinks to fit the width is shorter than a line, and the slot must not follow it either
        ZStack {
            if let status {
                Text(status)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }
        }
        .frame(height: slotHeight)
        .font(.subheadline)
        .foregroundStyle(.secondary)
        .accessibilityIdentifier("status")
        .probeFrame("status")
    }
}
