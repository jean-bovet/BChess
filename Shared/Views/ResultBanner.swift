//
//  ResultBanner.swift
//  BChess
//
//  How the game ended, in the status line's slot: who won (or a draw) and why.
//

import SwiftUI

struct ResultBanner: View {

    let result: GameResult

    @ScaledMetric(relativeTo: .headline) private var titleSize: CGFloat = 18
    @ScaledMetric(relativeTo: .headline) private var iconSize: CGFloat = 24
    /// The height of the title and of the reason: one line of Latin text. Fixed, because the line height of a script
    /// with taller fallback fonts (Arabic) is 2 pt more than the same line in English, and the board block, centred on
    /// the screen, would sit higher in that language (as for the status line's slot).
    @ScaledMetric(relativeTo: .headline) private var titleSlot: CGFloat = 22
    @ScaledMetric(relativeTo: .footnote) private var reasonSlot: CGFloat = 16

    private var symbol: String {
        result.winner == .draw ? "equal.circle.fill" : "crown.fill"
    }

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: symbol)
                .font(.system(size: iconSize))
                .foregroundStyle(Walnut.accent)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 2) {
                Text(GameText.resultTitle(result))
                    .font(.system(size: titleSize, weight: .semibold, design: .serif))
                    .foregroundStyle(Walnut.textPrimary)
                    .frame(height: titleSlot)
                if let reason = GameText.resultReason(result.reason) {
                    Text(reason)
                        .font(.footnote)
                        .foregroundStyle(Walnut.textSecondary)
                        .frame(height: reasonSlot)
                }
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .walnutCard()
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("result")
    }
}
