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
    /// Starts a new game in the library.
    let onNewGame: (GamePlayer, GamePlayer) -> Void
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    NewPlayerConfigurationView(title: "White Player", player: $temporaryWhitePlayer)
                    NewPlayerConfigurationView(title: "Black Player", player: $temporaryBlackPlayer)
                }
                .padding(16)
            }
            .scrollDismissesKeyboard(.interactively)
            .background(Walnut.background.ignoresSafeArea())
            .onAppear() {
                temporaryWhitePlayer = session.gameState.white
                temporaryBlackPlayer = session.gameState.black
            }
            .navigationTitle(editMode ? "Players & Level" : "New Game")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(Walnut.background, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Text(editMode ? "Players & Level" : "New Game")
                        .font(.system(.headline, design: .serif, weight: .semibold))
                        .foregroundStyle(Walnut.textPrimary)
                        .accessibilityAddTraits(.isHeader)
                }

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
                        .fontWeight(.semibold)
                    } else {
                        Button("New Game") {
                            onNewGame(temporaryWhitePlayer, temporaryBlackPlayer)
                            dismiss()
                        }
                        .fontWeight(.semibold)
                    }
                }
            }
        }
    }
}

#if DEBUG
#Preview("New game") {
    PreviewScenarios.newGameNewGame.view()
}

#Preview("Edit game") {
    PreviewScenarios.newGameEditGame.view()
}
#endif
