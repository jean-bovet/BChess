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
                if let reason = GameText.resultReason(result.reason) {
                    Text(reason)
                        .font(.footnote)
                        .foregroundStyle(Walnut.textSecondary)
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
