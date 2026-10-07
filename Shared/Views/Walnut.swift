//
//  Walnut.swift
//  BChess
//
//  The palette of the app: warm paper, walnut and honey. Every color adapts to light and dark mode
//  through the asset catalog; the accent is the catalog's `AccentColor`.
//

import SwiftUI

enum Walnut {
    static let accent = Color("AccentColor")
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

/// One card of a form: a serif header above rows on a walnut card, divided by hairlines.
struct WalnutSection<Rows: View>: View {
    let title: LocalizedStringKey
    @ViewBuilder let rows: Rows

    init(_ title: LocalizedStringKey, @ViewBuilder rows: () -> Rows) {
        self.title = title
        self.rows = rows()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.system(.subheadline, design: .serif, weight: .semibold))
                .foregroundStyle(Walnut.textSecondary)
                .accessibilityAddTraits(.isHeader)
                .padding(.horizontal, 14)
            VStack(spacing: 0) {
                Group(subviews: rows) { subviews in
                    ForEach(subviews.indices, id: \.self) { index in
                        if index > 0 {
                            Walnut.cardBorder.frame(height: 1)
                        }
                        subviews[index]
                    }
                }
            }
            .walnutCard(radius: 16)
        }
    }
}

/// A serif row title with an optional caption hint.
struct WalnutRowLabel: View {
    let title: LocalizedStringKey
    let hint: LocalizedStringKey?

    init(_ title: LocalizedStringKey, _ hint: LocalizedStringKey? = nil) {
        self.title = title
        self.hint = hint
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(.system(.callout, design: .serif, weight: .semibold))
                .foregroundStyle(Walnut.textPrimary)
            if let hint {
                Text(hint)
                    .font(.caption)
                    .foregroundStyle(Walnut.textSecondary)
            }
        }
    }
}

/// A card row with a switch tinted with the accent.
struct WalnutToggleRow: View {
    let title: LocalizedStringKey
    let hint: LocalizedStringKey?
    @Binding var isOn: Bool

    init(_ title: LocalizedStringKey, _ hint: LocalizedStringKey? = nil, isOn: Binding<Bool>) {
        self.title = title
        self.hint = hint
        self._isOn = isOn
    }

    var body: some View {
        Toggle(isOn: $isOn) {
            WalnutRowLabel(title, hint)
        }
        .tint(Walnut.accent)
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
    }
}

/// A segmented control in the walnut palette: the chosen segment is the honey pill.
struct WalnutSegmented<Option: Hashable>: View {
    @Binding var selection: Option
    let options: [Option]
    let title: (Option) -> String

    var body: some View {
        HStack(spacing: 2) {
            ForEach(options, id: \.self) { option in
                let isSelected = option == selection
                Button {
                    selection = option
                } label: {
                    Text(title(option))
                        .font(.system(.callout, design: .serif, weight: .semibold))
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                        .frame(maxWidth: .infinity, minHeight: 32)
                        .foregroundStyle(isSelected ? Walnut.pillText : Walnut.textPrimary)
                        .background(isSelected ? Walnut.pillBackground : .clear, in: RoundedRectangle(cornerRadius: 8))
                        .contentShape(RoundedRectangle(cornerRadius: 8))
                }
                .buttonStyle(.plain)
                .accessibilityAddTraits(isSelected ? .isSelected : [])
            }
        }
        .padding(3)
        .background(Walnut.background, in: RoundedRectangle(cornerRadius: 11))
        .overlay(RoundedRectangle(cornerRadius: 11).strokeBorder(Walnut.cardBorder))
    }
}

/// A text field on a walnut fill with a hairline border and a readable placeholder.
struct WalnutTextField: View {
    let title: LocalizedStringKey
    @Binding var text: String

    init(_ title: LocalizedStringKey, text: Binding<String>) {
        self.title = title
        self._text = text
    }

    var body: some View {
        TextField(text: $text, prompt: Text(title).foregroundStyle(Walnut.textSecondary)) {
            Text(title)
        }
        .textFieldStyle(.plain)
        .font(.system(.body, design: .serif))
        .foregroundStyle(Walnut.textPrimary)
        .padding(.horizontal, 10)
        .frame(minHeight: 36)
        .background(Walnut.background, in: RoundedRectangle(cornerRadius: 9))
        .overlay(RoundedRectangle(cornerRadius: 9).strokeBorder(Walnut.cardBorder))
    }
}

/// A walnut button: the honey chip for the main action, a bordered card for the others.
struct WalnutButtonStyle: ButtonStyle {
    var prominent = false

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(.body, design: .serif, weight: .semibold))
            .foregroundStyle(prominent ? Walnut.scoreChipText : Walnut.textPrimary)
            .padding(.horizontal, 18)
            .frame(minHeight: 36)
            .background(prominent ? Walnut.scoreChip : Walnut.card, in: RoundedRectangle(cornerRadius: 10))
            .overlay(RoundedRectangle(cornerRadius: 10).strokeBorder(Walnut.cardBorder))
            .opacity(configuration.isPressed ? 0.7 : 1)
            .contentShape(RoundedRectangle(cornerRadius: 10))
    }
}

#if DEBUG
#Preview("Palette") {
    PreviewScenarios.walnutPalette.view()
}
#endif
