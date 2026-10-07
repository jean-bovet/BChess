//
//  VariationSelectionView.swift
//  BChess
//
//  Created by Jean Bovet on 5/15/21.
//  Copyright © 2021 Jean Bovet. All rights reserved.
//

import SwiftUI

/// The moves that can follow the position, as arrows on the board: the main line solid walnut, the
/// variations lighter. The square an arrow points to is tappable. `VariationCards` offers the same choice.
struct VariationSelectionView: View {
    
    let session: GameSession

    var body: some View {
        if session.variations.show {
            GeometryReader { geometry in
                let minSize: CGFloat = min(geometry.size.width, geometry.size.height)
                let squareSize: CGFloat = minSize / CGFloat(numberOfSquares)
                let xOffset: CGFloat = (geometry.size.width - minSize) / 2 + squareSize / 2
                let yOffset: CGFloat = (geometry.size.height - minSize) / 2 + squareSize / 2
                let rotated = session.gameState.rotated
                
                // The main line goes last, so that it stays on top where arrows cross
                ForEach(session.variations.choices.reversed()) { v in
                    let x1 = CGFloat(v.from.file.actual(rotated: rotated)) * squareSize + xOffset
                    let y1 = CGFloat(7 - v.from.rank.actual(rotated: rotated)) * squareSize + yOffset
                    let x2 = CGFloat(v.to.file.actual(rotated: rotated)) * squareSize + xOffset
                    let y2 = CGFloat(7 - v.to.rank.actual(rotated: rotated)) * squareSize + yOffset
                    let color = v.isMainLine ? Walnut.frame.opacity(0.85) : Color.accentColor.opacity(0.6)

                    Color.clear
                        .frame(width: squareSize, height: squareSize)
                        .contentShape(Rectangle())
                        .offset(x: x2 - squareSize/2, y: y2 - squareSize/2)
                        .onTapGesture {
                            session.chooseVariation(v.index)
                        }
                        .accessibilityElement()
                        .accessibilityLabel(v.label)
                        .accessibilityAddTraits(.isButton)

                    let p = Arrow(start: CGPoint(x: x1, y: y1),
                                  end: CGPoint(x: x2, y: y2),
                                  length: squareSize * 0.4).path
                    p.fill(color)
                    p.stroke(color, style: StrokeStyle(lineWidth: squareSize * 0.16, lineCap: .round, lineJoin: .round))
                        .allowsHitTesting(false)
                }
            }
        }
    }
}

/// A row of cards below the board, one per move on offer ("MAIN LINE 2…Nc6", "VARIATION 2…d6").
/// Tapping a card continues with that move. It is empty unless the variation choice is shown.
struct VariationCards: View {
    let session: GameSession

    var body: some View {
        if session.variations.show {
            VStack(alignment: .leading, spacing: 6) {
                Text("Several moves continue from here. Tap an arrow or a line.")
                    .font(.footnote)
                    .foregroundStyle(Walnut.textSecondary)
                    .padding(.horizontal, 2)
                HStack(spacing: 8) {
                    ForEach(session.variations.choices) { v in
                        let selected = v.index == session.variations.selectedVariationIndex
                        Button {
                            session.chooseVariation(v.index)
                        } label: {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(v.isMainLine ? "MAIN LINE" : "VARIATION")
                                    .font(.caption2.weight(.semibold))
                                    .tracking(0.3)
                                    .foregroundStyle(Walnut.textSecondary)
                                Text(v.label)
                                    .font(.callout.weight(selected ? .bold : .semibold))
                                    .foregroundStyle(Walnut.textPrimary)
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 10)
                            .walnutCard(radius: 12)
                            .overlay {
                                if selected {
                                    RoundedRectangle(cornerRadius: 12).strokeBorder(Walnut.frame, lineWidth: 2)
                                }
                            }
                        }
                        .buttonStyle(.plain)
                        .accessibilityIdentifier("variation-\(v.index)")
                    }
                }
            }
        }
    }
}

#if DEBUG
#Preview("Arrows and cards") {
    PreviewScenarios.variationArrowsAndCards.view()
}
#endif
