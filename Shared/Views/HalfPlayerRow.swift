//
//  HalfPlayerRow.swift
//  BChess
//
//  Created by Jean Bovet on 1/10/21.
//  Copyright © 2021 Jean Bovet. All rights reserved.
//

import SwiftUI

/// A face-to-face half's one row: whose move it is, who plays it, what it has captured, all on one line, and the game's
/// result once it is over. The single board keeps `PlayerRow` (a name line and a capture line of its own): two boards
/// share the screen, and a second line per half would cost each board 16 pt of its 370.
struct HalfPlayerRow: View {

    let session: GameSession
    let isWhite: Bool

    private var facts: PlayerRowFacts { PlayerRowFacts(session: session, isWhite: isWhite) }
    private var toMove: Bool { facts.toMove }
    private var name: String { facts.name }

    /// The line's result (`GameSession.result`): a half has no status line and no banner, so the row says it and
    /// both players read it, the far one turned with its half. It stays while browsing an earlier position.
    private var result: String? {
        session.result.map { GameText.resultDetail($0) }
    }

    /// The turn: shown while the game is on, and when browsing an earlier position of a finished game (the side to
    /// move there); at the line's end the result alone replaces it.
    private var turn: String? {
        result == nil || toMove ? facts.detail : nil
    }

    @Environment(\.colorScheme) private var colorScheme
    @ScaledMetric(relativeTo: .headline) private var nameSize: CGFloat = 18

    /// How the capture strip is drawn when the row is short of width.
    private enum Strip {
        /// 22 pt pieces, as wide as they need.
        case full
        /// 14 pt pieces.
        case small
        /// 14 pt pieces that give way: the strip takes what the row has (before the name) and clips at its trailing edge.
        case clipped

        var piece: CGFloat { self == .full ? 22 : 14 }
    }

    var body: some View {
        // 22 pt pieces when they fit, then 14 pt, then the name truncates and the strip clips, so a half never overflows
        ViewThatFits(in: .horizontal) {
            row(.full)
            row(.small)
            row(.clipped)
        }
        .padding(.horizontal, 2)
        .accessibilityElement(children: .combine)
    }

    private func row(_ strip: Strip) -> some View {
        HStack(spacing: 8) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text(name)
                    .font(.system(size: nameSize, weight: .semibold, design: .serif))
                    .foregroundStyle(Walnut.textPrimary)
                    .lineLimit(1)
                    .layoutPriority(1)
                // The accent says whose move it is
                if let turn {
                    Text(turn)
                        .font(.footnote.weight(toMove ? .semibold : .regular))
                        .foregroundStyle(toMove ? Color.accentColor : Walnut.textSecondary)
                        .lineLimit(1)
                }
                // The only sign of the result a half has: the captures give way first, then the name truncates, and
                // the result itself shrinks before it is ever cut
                if let result {
                    Text(result)
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(Color.accentColor)
                        .lineLimit(1)
                        .minimumScaleFactor(0.6)
                        .layoutPriority(3)
                }
            }
            // The name keeps its room; the clipped strip takes what is left of it
            .layoutPriority(strip == .clipped ? 2 : 0)

            Spacer(minLength: 0)

            let captured = session.capturedPieces(white: isWhite)
            if !captured.isEmpty {
                capturedStrip(captured, strip)
            }

            if let points = session.materialPoints(white: isWhite) {
                Text(points)
                    .font(.footnote)
                    .foregroundStyle(Walnut.textSecondary)
            }
        }
    }

    @ViewBuilder private func capturedStrip(_ captured: [String], _ strip: Strip) -> some View {
        let pieces = HStack(spacing: 0) {
            // By position: the same piece letter is captured more than once
            ForEach(Array(captured.enumerated()), id: \.offset) { _, piece in
                SquareView(piece: Piece(name: piece, file: 0, rank: 0))
                    .frame(width: strip.piece, height: strip.piece)
            }
        }
        // The black pieces are dark: in dark mode they sit on a light square's color
        .padding(.horizontal, colorScheme == .dark ? 6 : 0)
        .background(colorScheme == .dark ? Walnut.lightSquare : .clear, in: Capsule())
        if strip == .clipped {
            ClippedStrip { pieces }
                .clipped()
        } else {
            pieces
        }
    }
}

/// A strip that takes at most the width it is proposed (zero when proposed none) and clips at its trailing edge.
private struct ClippedStrip: Layout {
    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let ideal = subviews[0].sizeThatFits(.unspecified)
        let width = proposal.width.map { min($0, ideal.width) } ?? ideal.width
        return CGSize(width: width, height: ideal.height)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let ideal = subviews[0].sizeThatFits(.unspecified)
        subviews[0].place(at: CGPoint(x: bounds.minX, y: bounds.midY), anchor: .leading, proposal: ProposedViewSize(ideal))
    }
}
