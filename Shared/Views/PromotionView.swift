//
//  PromotionView.swift
//  BChess
//
//  Created by Jean Bovet on 1/15/21.
//  Copyright © 2021 Jean Bovet. All rights reserved.
//

import SwiftUI

/// The choice of piece for a promotion, laid over the board: the board dims and a column drops from the
/// promotion square toward the center of the board, with the queen first. Tapping outside cancels.
/// Lay it over a square of the board's size; `callback` gets the piece's name, or nil on cancel.
struct PromotionView: View {
    let promotion: Promotion
    let squareSize: CGFloat
    /// The column and the row of the promotion square on screen, row 0 at the top.
    let screenFile: Int
    let screenRow: Int
    let callback: (String?) -> Void

    private let cancelFraction: CGFloat = 0.75

    private var dropsDown: Bool {
        Promotion.dropsDown(screenRow: screenRow)
    }

    private var columnHeight: CGFloat {
        squareSize * (CGFloat(promotion.pieceNames.count) + cancelFraction)
    }

    private func choice(_ index: Int, _ name: String) -> some View {
        Button {
            callback(name)
        } label: {
            Image(Piece.pieceImageNames[name]!)
                .resizable()
                .aspectRatio(1.0, contentMode: .fit)
                .padding(squareSize * 0.04)
                .frame(width: squareSize, height: squareSize)
                .background(index == 0 ? Walnut.pillBackground : .clear)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(Self.label(of: name))
        .accessibilityIdentifier("promote-\(name.uppercased())")
    }

    private var cancelButton: some View {
        Button {
            callback(nil)
        } label: {
            Image(systemName: "xmark")
                .font(.system(size: squareSize * 0.3, weight: .bold))
                .foregroundStyle(Walnut.textSecondary)
                .frame(width: squareSize, height: squareSize * cancelFraction)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Cancel")
        .accessibilityIdentifier("promote-cancel")
    }

    private var column: some View {
        let choices = Array(promotion.pieceNames.enumerated())
        return VStack(spacing: 0) {
            // The first choice stays next to the promotion square, on either side of it
            if dropsDown {
                ForEach(choices, id: \.offset) { choice($0.offset, $0.element) }
                cancelButton
            } else {
                cancelButton
                ForEach(choices.reversed(), id: \.offset) { choice($0.offset, $0.element) }
            }
        }
        .frame(width: squareSize, height: columnHeight)
        .background(Walnut.card)
        .clipShape(UnevenRoundedRectangle(topLeadingRadius: dropsDown ? 0 : 8,
                                          bottomLeadingRadius: dropsDown ? 8 : 0,
                                          bottomTrailingRadius: dropsDown ? 8 : 0,
                                          topTrailingRadius: dropsDown ? 0 : 8))
        .shadow(color: .black.opacity(0.35), radius: 10, y: dropsDown ? 6 : -6)
    }

    var body: some View {
        ZStack(alignment: .topLeading) {
            Color(red: 0.165, green: 0.129, blue: 0.106).opacity(0.45)
                .contentShape(Rectangle())
                .onTapGesture { callback(nil) }
                .accessibilityHidden(true)
            column
                .offset(x: CGFloat(screenFile) * squareSize,
                        y: dropsDown ? CGFloat(screenRow) * squareSize
                                     : CGFloat(screenRow + 1) * squareSize - columnHeight)
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Promote to")
    }

    private static func label(of name: String) -> String {
        switch name.uppercased() {
        case "Q": return "Queen"
        case "R": return "Rook"
        case "B": return "Bishop"
        default: return "Knight"
        }
    }
}

#if DEBUG
#Preview("Drops from the top") {
    PreviewScenarios.promotionDropsFromTheTop.view()
}

#Preview("Rises from the bottom") {
    PreviewScenarios.promotionRisesFromTheBottom.view()
}
#endif
