//
//  MoveStrip.swift
//  BChess
//
//  The last few whole moves on one line, with a button for the whole list.
//

import SwiftUI

struct MoveStrip: View {

    /// The most moves a strip shows: the widest one that fits whole beside the button wins.
    static let maximumMoves = 8
    /// The candidates from this one on (the last two) show the button as its icon only, to leave the width to the moves.
    static let iconOnlyCandidates = 2

    let session: GameSession
    let showAll: () -> Void

    /// One callout line of Latin text (20 pt at the default size), a fixed height: the same line in Arabic is 1.3 pt
    /// taller, and the strip, whose height sets the board block's, must not depend on the language.
    @ScaledMetric(relativeTo: .callout) private var textHeight: CGFloat = 20

    var body: some View {
        let current = session.currentMoveUUID
        // Candidates of 8, 7 ... 1 moves, each ending on the current move; SwiftUI takes the first that fits whole, so
        // no move is cut at the leading edge and the current one is always fully visible
        ViewThatFits(in: .horizontal) {
            ForEach(Array((1...Self.maximumMoves).reversed()), id: \.self) { count in
                let isLast = count == 1
                HStack(spacing: 6) {
                    moves(count: count, current: current, fits: !isLast)
                    movesButton(iconOnly: count <= Self.iconOnlyCandidates, showsVariations: !isLast)
                }
                .probeFrame("move-strip")
            }
        }
        // Past the second accessibility size the strip would not fit even one move; the list itself scales further
        .dynamicTypeSize(...DynamicTypeSize.accessibility2)
        .font(.callout)
    }

    /// The strip itself. Moves read left to right, the newest at the right edge, in every language; the button beside
    /// it keeps mirroring. Every candidate but the last keeps its ideal width (so `ViewThatFits` can reject it); the
    /// last takes the width it is offered and shrinks its text rather than being clipped.
    @ViewBuilder
    private func moves(count: Int, current: UInt, fits: Bool) -> some View {
        let tokens = session.game.recentMoves(current: current, count: count)
        let strip = HStack(spacing: 4) {
            ForEach(Array(tokens.enumerated()), id: \.offset) { _, token in
                if case .move(let label, let uuid) = token {
                    let isCurrent = uuid == current
                    Button { session.selectMove(uuid: uuid) } label: {
                        Text(label)
                            .fontWeight(isCurrent ? .bold : .regular)
                            .lineLimit(1)
                            .frame(height: textHeight)
                            .padding(.vertical, 6)
                            .padding(.horizontal, isCurrent ? 10 : 8)
                            .currentMovePill(isCurrent)
                    }
                    .buttonStyle(.plain)
                }
            }
            if tokens.isEmpty {
                Text("No moves yet")
                    .foregroundStyle(Walnut.textSecondary)
                    .frame(height: textHeight + 12)
            }
        }
        if fits {
            HStack(spacing: 0) {
                strip.fixedSize()
                Spacer(minLength: 0)
            }
            .environment(\.layoutDirection, .leftToRight)
        } else {
            strip
                .minimumScaleFactor(0.5)
                .frame(maxWidth: .infinity, alignment: .leading)
                .environment(\.layoutDirection, .leftToRight)
        }
    }

    /// The variation count is left out of the last candidate (the one-move fallback), whose width budget does not count it;
    /// the Moves sheet still shows the variations.
    private func movesButton(iconOnly: Bool, showsVariations: Bool) -> some View {
        Button(action: showAll) {
            HStack(spacing: 4) {
                Image(systemName: "list.bullet")
                if !iconOnly {
                    Text("Moves")
                }
                if showsVariations && session.game.variationCount > 0 {
                    Text(verbatim: GameText.notation("\u{2442}\(session.game.variationCount)"))
                }
            }
            .font(.footnote.weight(.semibold))
            .padding(.horizontal, 10)
            .frame(height: 32)
            .foregroundStyle(Color.accentColor)
            .walnutCard(radius: 16)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("All moves")
        .probeFrame("moves-button")
    }
}
