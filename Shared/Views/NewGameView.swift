//
//  NewGameView.swift
//  BChess
//
//  Created by Jean Bovet on 4/25/21.
//  Copyright © 2021 Jean Bovet. All rights reserved.
//

import SwiftUI

struct NewPlayerConfigurationView: View {
    
    @Binding var player: GamePlayer

    var body: some View {
        VStack(alignment: .leading) {
            TextField("Name", text: $player.name)
            Toggle(isOn: $player.computer) {
                Text("Computer")
                    .fixedSize()
            }
            Picker(selection: $player.level, label: Text("Level")) {
                Text("2 seconds").tag(0)
                Text("5 seconds").tag(1)
                Text("10 seconds").tag(2)
                Text("15 seconds").tag(3)
            }
            .hide(!player.computer, remove: true)
        }.padding()
    }
}

/// The players and their level, as a sheet of the game window.
struct NewGameView: View {
    
    @Environment(\.dismiss) private var dismiss

    let session: GameSession

    @State private var temporaryWhitePlayer = GamePlayer(name: "", computer: true, level: 0)
    @State private var temporaryBlackPlayer = GamePlayer(name: "", computer: true, level: 0)

    var body: some View {
        VStack {
            Text("Players & Level").font(.headline)
            GroupBox(label: Text("White Player").bold()) {
                NewPlayerConfigurationView(player: $temporaryWhitePlayer)
            }
            GroupBox(label: Text("Black Player").bold()) {
                NewPlayerConfigurationView(player: $temporaryBlackPlayer)
            }
            
            HStack {
                Spacer()
                Button("Cancel") {
                    dismiss()
                }
                .keyboardShortcut(.cancelAction)
                Button("OK") {
                    session.setPlayers(white: temporaryWhitePlayer, black: temporaryBlackPlayer)
                    session.requestEngineMoveIfNeeded()
                    dismiss()
                }
                .keyboardShortcut(.defaultAction)
            }
        }
        .padding()
        .onAppear() {
            temporaryWhitePlayer = session.gameState.white
            temporaryBlackPlayer = session.gameState.black
        }
    }
}

#Preview("Players & Level") {
    NewGameView(session: GameSession())
}
