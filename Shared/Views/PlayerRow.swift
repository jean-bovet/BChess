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

    private var facts: PlayerRowFacts { PlayerRowFacts(session: session, isWhite: isWhite) }
    private var toMove: Bool { facts.toMove }
    private var name: String { facts.name }
    private var detail: String { facts.detail }

    @Environment(\.colorScheme) private var colorScheme
    @ScaledMetric(relativeTo: .headline) private var nameSize: CGFloat = 18

    /// Past this many captured pieces the pieces overlap by 4 pt, so the capture line stays short; a row offered less
    /// width than that makes them overlap more.
    private static let overlapThreshold = 12
    private static let crowdedOverlap: CGFloat = -4

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            // The whole row width is the name's and the detail's: nothing else on this line
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text(name)
                    .font(.system(size: nameSize, weight: .semibold, design: .serif))
                    .foregroundStyle(Walnut.textPrimary)
                    .lineLimit(1)
                    // A long name gives way only when it alone exceeds the row
                    .layoutPriority(1)
                // The accent says whose move it is
                Text(detail)
                    .font(.footnote.weight(toMove ? .semibold : .regular))
                    .foregroundStyle(toMove ? Color.accentColor : Walnut.textSecondary)
                    .lineLimit(1)
                Spacer(minLength: 0)
            }

            IdealAsMinimum {
                captureLine
            }
        }
        .padding(.horizontal, 2)
        .accessibilityElement(children: .combine)
    }

    /// The captured pieces and the material points: always 22 pt tall, so the first capture never moves the board, and
    /// never wider than the row: the pieces overlap as much as the width needs, the points stay whole.
    private var captureLine: some View {
        let captured = session.capturedPieces(white: isWhite)
        let points = session.materialPoints(white: isWhite)
        let dark = colorScheme == .dark
        return CaptureLine(overlap: captured.count > Self.overlapThreshold ? Self.crowdedOverlap : 0,
                           piecesPadding: dark && !captured.isEmpty ? 6 : 0) {
            // The black pieces are dark: in dark mode they sit on a capsule of a light square's color
            if dark && !captured.isEmpty {
                Capsule()
                    .fill(Walnut.lightSquare)
                    .layoutValue(key: CaptureLine.Role.self, value: .backdrop)
            }
            // By position: the same piece letter is captured more than once
            ForEach(Array(captured.enumerated()), id: \.offset) { _, piece in
                SquareView(piece: Piece(name: piece, file: 0, rank: 0))
                    .frame(width: CaptureLine.side, height: CaptureLine.side)
                    .layoutValue(key: CaptureLine.Role.self, value: .piece)
            }
            if let points {
                Text(points)
                    .font(.footnote)
                    .foregroundStyle(Walnut.textSecondary)
                    .fixedSize()
                    .probeFrame(isWhite ? "points-white" : "points-black")
                    .layoutValue(key: CaptureLine.Role.self, value: .points)
            }
        }
        .probeFrame(isWhite ? "captures-white" : "captures-black")
        .frame(maxWidth: .infinity, minHeight: CaptureLine.side, maxHeight: CaptureLine.side, alignment: .leading)
    }
}

/// Reports its content's ideal width as its minimum: the wide layout's `BoardColumn` takes its floor from the rows'
/// minimum width, and a row stays as wide as its captured pieces at their ideal overlap, never squeezed to a sliver.
/// (The capture line itself reports its true minimum; a finite width it is actually given still squeezes the pieces.)
private struct IdealAsMinimum: Layout {
    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        guard let subview = subviews.first else {
            return .zero
        }
        guard proposal.width == 0 else {
            return subview.sizeThatFits(proposal)
        }
        return subview.sizeThatFits(ProposedViewSize(width: nil, height: proposal.height))
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        subviews.first?.place(at: bounds.origin, anchor: .topLeading, proposal: ProposedViewSize(bounds.size))
    }
}

/// The capture line's layout: the captured pieces side by side (each `side` wide, with a backdrop behind them in dark
/// mode), then the material points. Their ideal width has the pieces overlap by `overlap` (zero for a few, negative past
/// twelve); offered less width than that the pieces overlap more, down to `minimumStep` between two of them, so the line
/// is never wider than it is offered and never wraps, and the points stay whole. Its minimum (a proposal of zero) is the
/// squeezed width: 22 + `minimumStep` for each further piece, the padding, the gap and the points; an unspecified
/// proposal is the ideal width.
struct CaptureLine: Layout {

    enum Kind { case piece, backdrop, points }

    struct Role: LayoutValueKey {
        static let defaultValue = Kind.piece
    }

    static let side: CGFloat = 22
    /// The least distance between two pieces' leading edges: a sliver of each still shows.
    static let minimumStep: CGFloat = 2
    /// Between the pieces and the points.
    static let gap: CGFloat = 8

    /// The spacing between two pieces at the ideal width.
    var overlap: CGFloat
    /// The backdrop's margin on each side of the pieces.
    var piecesPadding: CGFloat

    private struct Measure {
        var pieces: Int
        var step: CGFloat
        var pointsWidth: CGFloat
        var width: CGFloat

        var piecesWidth: CGFloat {
            pieces == 0 ? 0 : CaptureLine.side * CGFloat(pieces) + step * CGFloat(pieces - 1)
        }
    }

    private func measure(width: CGFloat?, _ subviews: Subviews) -> Measure {
        let pieces = subviews.filter { $0[Role.self] == .piece }.count
        let pointsWidth = subviews.first { $0[Role.self] == .points }?.sizeThatFits(.unspecified).width ?? 0
        let gap = pieces > 0 && pointsWidth > 0 ? Self.gap : 0
        var step = overlap
        if pieces > 1, let width, width.isFinite, width >= 0 {
            let room = width - pointsWidth - gap - 2 * piecesPadding
            let fitting = (room - Self.side * CGFloat(pieces)) / CGFloat(pieces - 1)
            step = min(overlap, max(fitting, Self.minimumStep - Self.side))
        }
        var result = Measure(pieces: pieces, step: step, pointsWidth: pointsWidth, width: 0)
        let padding = pieces > 0 ? 2 * piecesPadding : 0
        result.width = result.piecesWidth + padding + gap + pointsWidth
        return result
    }

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        CGSize(width: measure(width: proposal.width, subviews).width, height: Self.side)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let measured = measure(width: bounds.width, subviews)
        let piecesLeading = bounds.minX + piecesPadding
        var x = piecesLeading
        for subview in subviews {
            switch subview[Role.self] {
            case .backdrop:
                subview.place(at: CGPoint(x: bounds.minX, y: bounds.minY), anchor: .topLeading,
                              proposal: ProposedViewSize(width: measured.piecesWidth + 2 * piecesPadding, height: Self.side))
            case .piece:
                subview.place(at: CGPoint(x: x, y: bounds.minY), anchor: .topLeading,
                              proposal: ProposedViewSize(width: Self.side, height: Self.side))
                x += Self.side + measured.step
            case .points:
                let leading = measured.pieces > 0 ? piecesLeading + measured.piecesWidth + piecesPadding + Self.gap : bounds.minX
                subview.place(at: CGPoint(x: leading, y: bounds.midY), anchor: .leading, proposal: .unspecified)
            }
        }
    }
}

/// What every player row says about one side, whichever layout draws it (`PlayerRow`, `HalfPlayerRow`): who it is,
/// whether it is to move in the position on screen, and its detail.
@MainActor struct PlayerRowFacts {

    let session: GameSession
    let isWhite: Bool

    var player: GamePlayer {
        isWhite ? session.gameState.white : session.gameState.black
    }

    var opponent: GamePlayer {
        isWhite ? session.gameState.black : session.gameState.white
    }

    var toMove: Bool {
        session.isWhiteToMove == isWhite && session.gameEnd == .none
    }

    var name: String {
        GameText.name(of: player, isWhite: isWhite, opponent: opponent)
    }

    /// The colour with what the player is doing (whose move it is, the computer's thinking).
    var detail: String {
        GameText.sideDetail(of: player, isWhite: isWhite, opponent: opponent, toMove: toMove,
                            isThinking: session.isThinking)
    }
}
