//
//  ContentView.swift
//  Shared
//
//  Created by Jean Bovet on 1/7/21.
//  Copyright © 2021 Jean Bovet. All rights reserved.
//

import SwiftUI

struct ContentView: View {
    let session: GameSession
    /// Starts a new game somewhere else than in place (the iOS library). Nil resets the session.
    var onNewGame: ((GamePlayer, GamePlayer) -> Void)? = nil
            
    @State private var showInfo = true
    
    @State private var showNewGameSheet = false
    @State private var newGameSheetEditMode = false

    var body: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading) {
                ColorInformationView(session: session, isWhite: session.gameState.rotated ? true: false)
                ZStack {
                    BoardView(session: session)
                        .if(session.mode.value == .analyze) {
                            $0.border(Color.yellow, width: 4)
                        }
                        .if(session.mode.value == .train) {
                            $0.border(Color.green, width: 4)
                        }
                    LabelsView(session: session)
                    PiecesView(session: session)
                    VariationSelectionView(session: session)
                }
                .accessibilityElement(children: .contain)
                .accessibilityIdentifier("board")
                .accessibilityValue(session.fen)
                .padding()
                .padding(.bottom, 20) // Because the labels are "leaking" a bit below the board space itself
                ColorInformationView(session: session, isWhite: session.gameState.rotated ? false: true)
            }
            
            if (showInfo) {
#if os(macOS)
                VStack(alignment: .leading, spacing: 10) {
                    NavigationActionView(session: session)
                    InformationView(session: session)
                }
                .frame(minWidth: 350, idealWidth: 350, maxWidth: 350, alignment: .leading)
#endif
            }
        }
        .padding()
        .toolbar {
            ActionsToolbar(session: session,
                           showInfo: $showInfo,
                           showNewGameSheet: $showNewGameSheet,
                           newGameSheetEditMode: $newGameSheetEditMode)
        }
        .onAppear {
            // The engine waits for the move animation before it replies
            session.animate = { change, completion in
                withAnimation(.default, completionCriteria: .logicallyComplete, change, completion: completion)
            }
        }
        .sheet(isPresented: $showNewGameSheet) {
            #if os(macOS)
            NewGameView(session: session, editMode: newGameSheetEditMode)
            #else
            NewGameView_iOS(session: session, editMode: newGameSheetEditMode, onNewGame: onNewGame)
            #endif
        }
    }
}

#Preview("Analyze") {
    ContentView(session: GameSession(mode: GameMode(value: .analyze)))
}

#Preview("Train") {
    ContentView(session: GameSession(mode: GameMode(value: .train)))
}

#Preview("Rotated") {
    ContentView(session: GameSession(state: GameState(pgn: "*", rotated: true)))
}
