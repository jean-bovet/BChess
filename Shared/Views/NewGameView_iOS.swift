//
//  NewGameView_iOS.swift
//  BChess
//
//  Created by Jean Bovet on 4/25/21.
//  Copyright © 2021 Jean Bovet. All rights reserved.
//

import SwiftUI

struct NewGameView_iOS: View {
    
    @Environment(\.dismiss) private var dismiss

    let session: GameSession

    @State private var temporaryWhitePlayer = GamePlayer(name: "", computer: true, level: 0)
    @State private var temporaryBlackPlayer = GamePlayer(name: "", computer: true, level: 0)

    var editMode: Bool
    /// Starts the game elsewhere than in place; nil resets the session.
    var onNewGame: ((GamePlayer, GamePlayer) -> Void)? = nil
    
    var body: some View {
        NavigationStack {
            Form {
                Section(header: Text("White Player").bold()) {
                    NewPlayerConfigurationView(player: $temporaryWhitePlayer)
                }
                Section(header: Text("Black Player").bold()) {
                    NewPlayerConfigurationView(player: $temporaryBlackPlayer)
                }
            }
            .onAppear() {
                temporaryWhitePlayer = session.gameState.white
                temporaryBlackPlayer = session.gameState.black
            }
            .navigationTitle(editMode ? "Settings" : "New Game")
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .navigationBarTrailing) {
                    if editMode {
                        Button("OK") {
                            session.setPlayers(white: temporaryWhitePlayer, black: temporaryBlackPlayer)
                            session.requestEngineMoveIfNeeded()
                            dismiss()
                        }
                    } else {
                        Button("New Game") {
                            if let onNewGame {
                                onNewGame(temporaryWhitePlayer, temporaryBlackPlayer)
                            } else {
                                session.newGame(white: temporaryWhitePlayer, black: temporaryBlackPlayer)
                                session.requestEngineMoveIfNeeded()
                            }
                            dismiss()
                        }
                    }
                }
            }
        }
    }
}

#Preview("New game") {
    NewGameView_iOS(session: GameSession(), editMode: false)
}

#Preview("Edit game") {
    NewGameView_iOS(session: GameSession(), editMode: true)
}
