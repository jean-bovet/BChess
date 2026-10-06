//
//  Walnut.swift
//  BChess
//
//  The palette of the app: warm paper, walnut and honey. Every color adapts to light and dark mode
//  through the asset catalog; the accent is the catalog's `AccentColor`.
//

import SwiftUI

enum Walnut {
    static let background = Color("WalnutBackground")
    static let card = Color("WalnutCard")
    static let cardBorder = Color("WalnutCardBorder")
    static let textPrimary = Color("WalnutTextPrimary")
    static let textSecondary = Color("WalnutTextSecondary")
    static let lightSquare = Color("WalnutLightSquare")
    static let darkSquare = Color("WalnutDarkSquare")
    static let frame = Color("WalnutFrame")
    static let coordinates = Color("WalnutCoordinates")
    static let lastMove = Color("WalnutLastMove")
    static let pillBackground = Color("WalnutPillBackground")
    static let pillText = Color("WalnutPillText")
    static let scoreChip = Color("WalnutScoreChip")
    static let scoreChipText = Color("WalnutScoreChipText")

    /// The frame is a third of a square thick: with 8 squares, 1/26 of the board's side.
    static let frameFraction: CGFloat = 1.0 / 26.0
}

/// A white card with a hairline border, the surface of the engine readout and the move list.
private struct CardModifier: ViewModifier {
    let radius: CGFloat

    func body(content: Content) -> some View {
        content
            .background(Walnut.card, in: RoundedRectangle(cornerRadius: radius))
            .overlay(RoundedRectangle(cornerRadius: radius).strokeBorder(Walnut.cardBorder))
    }
}

extension View {
    func walnutCard(radius: CGFloat = 10) -> some View {
        modifier(CardModifier(radius: radius))
    }

    /// The honey pill behind the current move.
    func currentMovePill(_ isCurrent: Bool, radius: CGFloat = 8) -> some View {
        self
            .foregroundStyle(isCurrent ? Walnut.pillText : Walnut.textSecondary)
            .background(isCurrent ? Walnut.pillBackground : .clear, in: RoundedRectangle(cornerRadius: radius))
    }
}

#Preview("Palette") {
    VStack(alignment: .leading, spacing: 12) {
        HStack(spacing: 0) {
            ForEach(0..<8, id: \.self) { i in
                (i % 2 == 0 ? Walnut.lightSquare : Walnut.darkSquare).frame(width: 30, height: 30)
            }
        }
        .padding(8)
        .background(Walnut.frame)
        Text("Primary").foregroundStyle(Walnut.textPrimary)
        Text("Secondary").foregroundStyle(Walnut.textSecondary)
        Text("5…f6").padding(.horizontal, 10).padding(.vertical, 6).currentMovePill(true)
        Text("Card").padding().walnutCard()
        Button("Accent") {}
    }
    .padding()
    .background(Walnut.background)
}
