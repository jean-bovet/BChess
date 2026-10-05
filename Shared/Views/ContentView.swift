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
            
    @AppStorage("showInformationPanel") private var showInfo = true

    @State private var showNewGameSheet = false
    @State private var newGameSheetEditMode = false

    /// The information panel sits beside the board when there is more width than height,
    /// and below it otherwise (iPhone in portrait). The Mac is always wide.
    @State private var isWide = true

    private var layout: AnyLayout {
        isWide ? AnyLayout(HStackLayout(alignment: .top)) : AnyLayout(VStackLayout(alignment: .leading))
    }

    var body: some View {
        layout {
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
                // Keeps the greedy GeometryReader layers from taking more than the board's square
                .aspectRatio(1, contentMode: .fit)
                .accessibilityElement(children: .contain)
                .accessibilityIdentifier("board")
                .accessibilityValue(session.fen)
                .padding()
                .padding(.bottom, 20) // Because the labels are "leaking" a bit below the board space itself
                ColorInformationView(session: session, isWhite: session.gameState.rotated ? false: true)
            }
            // The board gets its full size first; the panel takes what is left
            .layoutPriority(1)

            if showInfo {
                VStack(alignment: .leading, spacing: 10) {
                    NavigationActionView(session: session)
                    InformationView(session: session)
                }
                .frame(minWidth: isWide ? 350 : nil, idealWidth: isWide ? 350 : nil, maxWidth: isWide ? 350 : .infinity,
                       maxHeight: .infinity, alignment: .topLeading)
                .transition(.opacity)
            }
        }
        .padding()
        #if os(iOS)
        .onGeometryChange(for: Bool.self) { proxy in
            proxy.size.width > proxy.size.height
        } action: { wide in
            isWide = wide
        }
        #endif
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
