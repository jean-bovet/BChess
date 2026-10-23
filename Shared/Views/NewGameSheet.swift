//
//  NewGameSheet.swift
//  BChess
//
//  The New Game sheet and, in its edit mode, the Players sheet: the opponent ladder (a friend and five computer
//  strengths) above a card with the side, the names and, at Maximum, the thinking time.
//

import SwiftUI

struct NewGameSheet: View {

    enum Mode {
        /// A new game: the primary button reads like the opponent and the choice is remembered.
        case new
        /// The players of the game on screen: "Done", and nothing is remembered.
        case edit
    }

    let mode: Mode
    let onDone: (NewGame) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var choice: NewGame

    init(choice: NewGame, mode: Mode, onDone: @escaping (NewGame) -> Void) {
        _choice = State(initialValue: choice)
        self.mode = mode
        self.onDone = onDone
    }

    private var title: String { mode == .new ? "New Game" : "Players" }
    private var buttonTitle: String { mode == .new ? choice.playLabel : "Done" }
    private var sides: [NewGame.Side] { mode == .new ? [.white, .random, .black] : [.white, .black] }

    private func done() {
        if mode == .new {
            choice.remember(in: .standard)
        }
        onDone(choice)
        dismiss()
    }

    private func sideTitle(_ side: NewGame.Side) -> String {
        switch side {
        case .white: "White"
        case .random: "Random"
        case .black: "Black"
        }
    }

    // MARK: Pieces

    private func tile(_ opponent: NewGame.Opponent, size: CGFloat) -> some View {
        Image(opponent.pieceImage)
            .resizable()
            .scaledToFit()
            .padding(size * 0.12)
            .frame(width: size, height: size)
            .background(opponent == .friend ? Walnut.background : Walnut.pillBackground, in: RoundedRectangle(cornerRadius: 8))
            .accessibilityHidden(true)
    }

    private func row(_ opponent: NewGame.Opponent, tileSize: CGFloat) -> some View {
        let isSelected = choice.opponent == opponent
        return Button {
            choice.opponent = opponent
        } label: {
            HStack(spacing: 12) {
                tile(opponent, size: tileSize)
                VStack(alignment: .leading, spacing: 2) {
                    HStack(alignment: .firstTextBaseline) {
                        Text(opponent.name)
                            .font(.system(.body, design: .serif, weight: .semibold))
                            .foregroundStyle(Walnut.textPrimary)
                        if !opponent.elo.isEmpty {
                            Text(opponent.elo)
                                .font(.caption.monospacedDigit())
                                .foregroundStyle(Walnut.textSecondary)
                        }
                    }
                    Text(opponent.blurb)
                        .font(.caption)
                        .foregroundStyle(Walnut.textSecondary)
                        .multilineTextAlignment(.leading)
                }
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Walnut.card, in: RoundedRectangle(cornerRadius: 14))
            .overlay(RoundedRectangle(cornerRadius: 14).strokeBorder(isSelected ? Walnut.accent : Walnut.cardBorder, lineWidth: isSelected ? 2 : 1))
            .contentShape(RoundedRectangle(cornerRadius: 14))
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
        .accessibilityIdentifier("new-game-opponent-\(String(describing: opponent))")
    }

    private func opponentList(tileSize: CGFloat, spacing: CGFloat) -> some View {
        VStack(spacing: spacing) {
            ForEach(NewGame.Opponent.allCases, id: \.self) { opponent in
                row(opponent, tileSize: tileSize)
            }
        }
    }

    private func field(_ label: String, text: Binding<String>, identifier: String) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(label)
                .font(.caption)
                .foregroundStyle(Walnut.textSecondary)
            WalnutTextField("Name", text: text)
                .accessibilityIdentifier(identifier)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var playersControls: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(choice.sideLabel)
                    .font(.system(.callout, design: .serif, weight: .semibold))
                    .foregroundStyle(Walnut.textPrimary)
                Spacer(minLength: 8)
                WalnutSegmented(selection: $choice.side, options: sides, title: sideTitle)
                    .frame(maxWidth: 230)
            }
            field(choice.firstNameLabel, text: $choice.firstName, identifier: "new-game-first-name")
            if choice.isFriend {
                field(choice.secondNameLabel, text: $choice.secondName, identifier: "new-game-second-name")
            }
            if choice.showsThinkingTime {
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Thinking time")
                            .font(.system(.callout, design: .serif, weight: .semibold))
                            .foregroundStyle(Walnut.textPrimary)
                        #if os(macOS)
                        Text("More time, stronger play.")
                            .font(.caption)
                            .foregroundStyle(Walnut.textSecondary)
                        #endif
                    }
                    Spacer(minLength: 8)
                    WalnutSegmented(selection: $choice.thinkingTime, options: NewGame.thinkingTimes) { "\(Int($0)) s" }
                        .frame(maxWidth: 230)
                }
            }
        }
    }

    // MARK: Layouts

    #if os(iOS)
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    Text("OPPONENT")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(Walnut.textSecondary)
                        .padding(.horizontal, 4)
                        .accessibilityHidden(true)
                    opponentList(tileSize: 40, spacing: 8)
                    playersControls
                        .padding(12)
                        .walnutCard(radius: 14)
                }
                .padding(16)
            }
            .scrollDismissesKeyboard(.interactively)
            .background(Walnut.background.ignoresSafeArea())
            .safeAreaInset(edge: .bottom) {
                Button(action: done) {
                    Text(buttonTitle)
                        .frame(maxWidth: .infinity, minHeight: 36)
                }
                .buttonStyle(WalnutButtonStyle(prominent: true))
                .accessibilityIdentifier("new-game-start")
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(Walnut.background)
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(Walnut.background, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Text(title)
                        .font(.system(.headline, design: .serif, weight: .semibold))
                        .foregroundStyle(Walnut.textPrimary)
                        .accessibilityAddTraits(.isHeader)
                }
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
    }
    #else
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(title)
                .font(.system(.title3, design: .serif, weight: .semibold))
                .foregroundStyle(Walnut.textPrimary)
                .accessibilityAddTraits(.isHeader)
                .frame(maxWidth: .infinity)
            HStack(alignment: .top, spacing: 16) {
                opponentList(tileSize: 32, spacing: 5)
                    .frame(width: 330)
                playersControls
                    .padding(12)
                    .frame(width: 300, alignment: .topLeading)
                    .walnutCard(radius: 12)
            }
            HStack {
                Spacer()
                Button("Cancel") { dismiss() }
                    .buttonStyle(WalnutButtonStyle())
                    .keyboardShortcut(.cancelAction)
                Button(buttonTitle, action: done)
                    .buttonStyle(WalnutButtonStyle(prominent: true))
                    .keyboardShortcut(.defaultAction)
                    .accessibilityIdentifier("new-game-start")
            }
        }
        .padding(20)
        .fixedSize(horizontal: false, vertical: true)
        .background(Walnut.background.ignoresSafeArea())
    }
    #endif
}
