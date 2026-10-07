//
//  NewGameView.swift
//  BChess
//
//  Created by Jean Bovet on 4/25/21.
//  Copyright © 2021 Jean Bovet. All rights reserved.
//

import SwiftUI

/// The levels the engine can play at, as the segments of the level control.
private let playerLevels = [0, 1, 2, 3]

private func levelTitle(_ level: Int) -> String {
    switch level {
    case 1: "5 s"
    case 2: "10 s"
    case 3: "15 s"
    default: "2 s"
    }
}

/// One player as a walnut card: the name, whether the engine plays, and its level.
struct NewPlayerConfigurationView: View {

    let title: LocalizedStringKey
    @Binding var player: GamePlayer

    var body: some View {
        WalnutSection(title) {
            WalnutTextField("Name", text: $player.name)
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
            WalnutToggleRow("Computer", isOn: $player.computer)
            if player.computer {
                VStack(alignment: .leading, spacing: 10) {
                    WalnutRowLabel("Level", "Thinking time per move")
                    WalnutSegmented(selection: $player.level, options: playerLevels, title: levelTitle)
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
            }
        }
    }
}

/// The players and their level, as a sheet of the game window.
struct NewGameView: View {
    
    @Environment(\.dismiss) private var dismiss

    let session: GameSession

    @State private var temporaryWhitePlayer = GamePlayer(name: "", computer: true, level: 0)
    @State private var temporaryBlackPlayer = GamePlayer(name: "", computer: true, level: 0)

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("Players & Level")
                .font(.system(.title3, design: .serif, weight: .semibold))
                .foregroundStyle(Walnut.textPrimary)
                .accessibilityAddTraits(.isHeader)
                .frame(maxWidth: .infinity)
            NewPlayerConfigurationView(title: "White Player", player: $temporaryWhitePlayer)
            NewPlayerConfigurationView(title: "Black Player", player: $temporaryBlackPlayer)

            HStack {
                Spacer()
                Button("Cancel") {
                    dismiss()
                }
                .buttonStyle(WalnutButtonStyle())
                .keyboardShortcut(.cancelAction)
                Button("OK") {
                    session.setPlayers(white: temporaryWhitePlayer, black: temporaryBlackPlayer)
                    session.requestEngineMoveIfNeeded()
                    dismiss()
                }
                .buttonStyle(WalnutButtonStyle(prominent: true))
                .keyboardShortcut(.defaultAction)
            }
        }
        .padding(20)
        #if os(macOS)
        .frame(width: 460)
        .fixedSize(horizontal: false, vertical: true)
        #endif
        .background(Walnut.background.ignoresSafeArea())
        .onAppear() {
            temporaryWhitePlayer = session.gameState.white
            temporaryBlackPlayer = session.gameState.black
        }
    }
}

#if DEBUG
#Preview("Players & Level") {
    PreviewScenarios.newGamePlayersAndLevel.view()
}
#endif
